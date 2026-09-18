defmodule Bazaar.Handler.Defaults do
  @moduledoc """
  The callbacks `use Bazaar.Handler, shop: ..., store: ...` defines, as
  plain functions taking the handler module first. A handler that overrides
  one of its callbacks can still call the default from here.

  Every function reads the handler's `Bazaar.Shop` and `Bazaar.Store`
  through `handler.__bazaar__/1`, keeps the checkout state in the store,
  and answers with the document `Bazaar.Checkout`, `Bazaar.Cart`,
  `Bazaar.Catalog` or `Bazaar.Location` builds from the shop's facts.
  """

  alias Bazaar.{Cart, Catalog, Checkout, Location, Order}

  # Checkouts

  @doc "Create, or convert the cart named by `cart_id` (once; a repeat answers the same checkout)."
  def create_checkout(handler, %{"cart_id" => cart_id} = params, conn) do
    store = store(handler)

    case {store.checkout_for_cart(cart_id), store.get_cart(cart_id)} do
      {checkout_id, _cart} when is_binary(checkout_id) ->
        get_checkout(handler, checkout_id, conn)

      {nil, nil} ->
        {:error, :not_found}

      {nil, cart} ->
        state = cart |> Checkout.from_cart(params, update_opts(handler)) |> store.put_checkout()
        store.put_checkout_for_cart(cart_id, state.id)
        {:ok, build(handler, state)}
    end
  end

  def create_checkout(handler, params, _conn) do
    state = params |> Checkout.new(update_opts(handler)) |> store(handler).put_checkout()
    {:ok, build(handler, state)}
  end

  def get_checkout(handler, id, _conn) do
    case store(handler).get_checkout(id) do
      nil -> {:error, :not_found}
      state -> {:ok, build(handler, state)}
    end
  end

  def update_checkout(handler, id, params, _conn) do
    with {:ok, state} <- open_checkout(handler, id) do
      state =
        state
        |> Checkout.apply_update(params, update_opts(handler))
        |> store(handler).put_checkout()

      {:ok, build(handler, state)}
    end
  end

  def cancel_checkout(handler, id, _conn) do
    case store(handler).get_checkout(id) do
      nil ->
        {:error, :not_found}

      %{status: :completed} ->
        {:error, :invalid_state}

      state ->
        {:ok, build(handler, %{state | status: :canceled} |> store(handler).put_checkout())}
    end
  end

  @doc """
  Applies the final update, then completes when the checkout is ready: no
  error messages, fulfillment selected when the handler advertises it, and
  the shop's `authorize/1` accepting the instruments. The order comes from
  `Bazaar.Order.from_checkout/3` and the shop's `order_placed/2` hears of it.
  """
  def complete_checkout(handler, id, params, conn) do
    shop = shop(handler)
    store = store(handler)

    with {:ok, state} <- open_checkout(handler, id) do
      state = state |> Checkout.apply_update(params, update_opts(handler)) |> store.put_checkout()
      checkout = build(handler, state)

      cond do
        :fulfillment in handler.capabilities() and not Checkout.fulfillment_ready?(checkout) ->
          message =
            Checkout.error(
              "missing",
              "A fulfillment destination and option must be selected",
              "$.fulfillment"
            )

          {:ok, build(handler, state, [message])}

        Enum.any?(checkout["messages"], &(&1["type"] == "error")) ->
          {:ok, checkout}

        true ->
          case shop.authorize(state.instruments) do
            :ok ->
              place_order(handler, state, checkout, conn)

            {:error, reason} ->
              {:ok,
               build(handler, state, [
                 Checkout.error("payment_failed", to_string(reason), "$.payment")
               ])}
          end
      end
    end
  end

  defp place_order(handler, state, checkout, conn) do
    shop = shop(handler)
    store = store(handler)
    order_id = "order_" <> random_id()

    order =
      checkout |> Order.from_checkout(order_id, order_url(shop, order_id)) |> store.put_order()

    state = store.put_checkout(%{state | status: :completed, order_id: order_id})
    shop.order_placed(order, conn)
    {:ok, build(handler, state)}
  end

  defp open_checkout(handler, id) do
    case store(handler).get_checkout(id) do
      nil -> {:error, :not_found}
      %{status: :open} = state -> {:ok, state}
      _closed -> {:error, :invalid_state}
    end
  end

  # Carts

  def create_cart(handler, params, _conn) do
    state = params |> Cart.new(update_opts(handler)) |> store(handler).put_cart()
    {:ok, build_cart(handler, state)}
  end

  def get_cart(handler, id, _conn) do
    case store(handler).get_cart(id) do
      nil -> {:error, :not_found}
      state -> {:ok, build_cart(handler, state)}
    end
  end

  def update_cart(handler, id, params, _conn) do
    case store(handler).get_cart(id) do
      nil ->
        {:error, :not_found}

      state ->
        state =
          state |> Cart.apply_update(params, update_opts(handler)) |> store(handler).put_cart()

        {:ok, build_cart(handler, state)}
    end
  end

  def cancel_cart(handler, id, _conn) do
    case store(handler).get_cart(id) do
      nil ->
        {:error, :not_found}

      state ->
        store(handler).delete_cart(id)
        {:ok, build_cart(handler, state)}
    end
  end

  # Orders

  def get_order(handler, id, _conn) do
    case store(handler).get_order(id) do
      nil -> {:error, :not_found}
      order -> {:ok, order}
    end
  end

  def update_order(handler, id, params, _conn) do
    with %{} = order <- store(handler).get_order(id) || {:error, :not_found},
         {:ok, order} <- Order.apply_update(order, params) do
      {:ok, store(handler).put_order(order)}
    end
  end

  @doc "Orders can't be canceled by default; override for what your fulfillment allows."
  def cancel_order(handler, id, _conn) do
    case store(handler).get_order(id) do
      nil -> {:error, :not_found}
      _order -> {:error, :invalid_state}
    end
  end

  # Catalog

  def search_products(handler, params, _conn) do
    products =
      shop(handler).products()
      |> Enum.filter(&text_matches?(&1["title"], &1["description"]["plain"], params["query"]))
      |> Catalog.filter(params["filters"])

    {page, pagination} = Catalog.paginate(products, params["pagination"])
    {:ok, %{"products" => page, "pagination" => pagination}}
  end

  def lookup_products(handler, %{"ids" => ids} = params, _conn) do
    {products, unknown} = Catalog.lookup(shop(handler).products(), ids)
    products = Catalog.filter(products, params["filters"])
    messages = for id <- unknown, do: info("not_found", "No product with id #{id}")
    {:ok, %{"products" => products, "messages" => messages}}
  end

  def get_product(handler, %{"id" => id} = params, _conn) do
    case Catalog.find(shop(handler).products(), id) do
      nil ->
        {:error, :not_found}

      product ->
        detail =
          Catalog.detail_product(product, params["selected"], preferences: params["preferences"])

        {:ok, %{"product" => detail}}
    end
  end

  # Locations

  def search_locations(handler, params, _conn) do
    shop = shop(handler)
    stores = Enum.filter(shop.locations(), &text_matches?(&1["name"], nil, params["query"]))

    with {:ok, locations} <- Location.filter(stores, params, location_opts(shop)) do
      {page, pagination} = Location.paginate(locations, params["pagination"])
      {:ok, %{"locations" => page, "pagination" => pagination}}
    end
  end

  def lookup_locations(handler, %{"ids" => ids} = params, _conn) do
    shop = shop(handler)
    {locations, messages} = Location.lookup(shop.locations(), ids)

    with {:ok, locations} <- Location.filter(locations, params, location_opts(shop)) do
      {:ok, %{"locations" => locations, "messages" => messages}}
    end
  end

  defp location_opts(shop), do: [serves: &shop.serves?/2, items: &shop.stocks?/2]

  # Documents from the shop's facts

  @doc "The checkout document for a state, from the handler's shop."
  def build(handler, state, messages \\ []) do
    shop = shop(handler)

    Checkout.build(state,
      item: &shop.item/1,
      fulfillment_options: &shop.fulfillment_options/2,
      pickup_locations: &shop.pickup_locations/1,
      discount: &shop.discount/2,
      payment_handlers: shop.payment_handlers(),
      links: shop.links(),
      order_url: &order_url(shop, &1),
      loyalty: &shop.loyalty/1,
      payment_terms: &shop.payment_terms/1,
      messages: messages
    )
  end

  @doc "The cart document for a state, from the handler's shop."
  def build_cart(handler, state) do
    shop = shop(handler)

    Cart.build(state,
      item: &shop.item/1,
      discount: &shop.discount/2,
      loyalty: &shop.loyalty/1,
      continue_url: shop.base_url() <> "/carts/" <> state.id
    )
  end

  defp update_opts(handler), do: [stored_addresses: &shop(handler).stored_addresses/1]

  defp order_url(shop, order_id), do: shop.base_url() <> "/orders/" <> order_id

  defp text_matches?(_title, _description, query) when query in [nil, ""], do: true

  defp text_matches?(title, description, query) do
    query = String.downcase(query)

    Enum.any?([title, description], fn text ->
      is_binary(text) and String.contains?(String.downcase(text), query)
    end)
  end

  defp info(code, content), do: %{"type" => "info", "code" => code, "content" => content}

  defp random_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)

  defp shop(handler), do: handler.__bazaar__(:shop)
  defp store(handler), do: handler.__bazaar__(:store)
end
