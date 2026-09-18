defmodule FlowerShop.Handler do
  @moduledoc """
  The flower shop's `Bazaar.Handler`.

  `bazaar_routes` in `FlowerShopWeb.Router` serves discovery, the catalog,
  checkouts and orders from these callbacks. `update_order/2` and `ship_order/1` back the
  app's own routes.
  """

  use Bazaar.Handler

  alias Bazaar.Signing.Key
  alias Bazaar.{Order, Platform, Webhook}
  alias FlowerShop.{Cart, Catalog, Checkout, Orders, Payments, Store}

  @impl true
  def capabilities,
    do: [:checkout, :orders, :fulfillment, :discount, :buyer_consent, :catalog, :cart, :location]

  @impl true
  def business_profile do
    handler = Catalog.payment_handler()

    %{
      "name" => "Flower Shop",
      "description" => "Bouquets, pots and orchids, shipped or picked up",
      "support_email" => "hello@flowershop.example",
      "payment_handlers" => [%{"name" => handler.namespace, "id" => handler.id, "config" => %{}}],
      "keys" => [Key.public_jwk(signing_key())]
    }
  end

  # Catalog: the query matches titles and descriptions, the spec's filters
  # and pagination come from Bazaar.Catalog.

  @impl true
  def search_products(params, _conn) do
    products =
      Catalog.products()
      |> Enum.filter(&matches?(&1, params["query"]))
      |> Bazaar.Catalog.filter(params["filters"])

    {page, pagination} = Bazaar.Catalog.paginate(products, params["pagination"])
    {:ok, %{"products" => page, "pagination" => pagination}}
  end

  defp matches?(_product, query) when query in [nil, ""], do: true

  defp matches?(product, query) do
    query = String.downcase(query)

    String.contains?(String.downcase(product["title"]), query) or
      String.contains?(String.downcase(product["description"]["plain"]), query)
  end

  @impl true
  def lookup_products(%{"ids" => ids} = params, _conn) do
    {products, unknown} = Bazaar.Catalog.lookup(Catalog.products(), ids)
    products = Bazaar.Catalog.filter(products, params["filters"])

    messages =
      for id <- unknown,
          do: %{"type" => "info", "code" => "not_found", "content" => "No product with id #{id}"}

    {:ok, %{"products" => products, "messages" => messages}}
  end

  @impl true
  def get_product(%{"id" => id} = params, _conn) do
    case Bazaar.Catalog.find(Catalog.products(), id) do
      nil ->
        {:error, :not_found}

      product ->
        detail =
          Bazaar.Catalog.detail_product(product, params["selected"],
            preferences: params["preferences"]
          )

        {:ok, %{"product" => detail}}
    end
  end

  # Locations: the query matches store names; distance, hours and amenities
  # are the library's, serving and stock are the shop's.

  @impl true
  def search_locations(params, _conn) do
    stores = Enum.filter(Catalog.locations(), &store_matches?(&1, params["query"]))

    with {:ok, locations} <- Bazaar.Location.filter(stores, params, location_opts()) do
      {page, pagination} = Bazaar.Location.paginate(locations, params["pagination"])
      {:ok, %{"locations" => page, "pagination" => pagination}}
    end
  end

  @impl true
  def lookup_locations(%{"ids" => ids} = params, _conn) do
    {locations, messages} = Bazaar.Location.lookup(Catalog.locations(), ids)

    with {:ok, locations} <- Bazaar.Location.filter(locations, params, location_opts()) do
      {:ok, %{"locations" => locations, "messages" => messages}}
    end
  end

  defp location_opts, do: [serves: &Catalog.serves?/2, items: &Catalog.stocks?/2]

  defp store_matches?(_location, query) when query in [nil, ""], do: true

  defp store_matches?(location, query),
    do: String.contains?(String.downcase(location["name"]), String.downcase(query))

  # Carts

  @impl true
  def create_cart(params, _conn) do
    state = Cart.new(params, base_url: base_url())
    Store.put_cart(state)
    {:ok, Cart.build(state)}
  end

  @impl true
  def get_cart(id, _conn) do
    case Store.get_cart(id) do
      nil -> {:error, :not_found}
      state -> {:ok, Cart.build(state)}
    end
  end

  @impl true
  def update_cart(id, params, _conn) do
    case Store.get_cart(id) do
      nil -> {:error, :not_found}
      state -> {:ok, state |> Cart.apply_update(params) |> Store.put_cart() |> Cart.build()}
    end
  end

  @impl true
  def cancel_cart(id, _conn) do
    case Store.get_cart(id) do
      nil ->
        {:error, :not_found}

      state ->
        Store.delete_cart(id)
        {:ok, Cart.build(state)}
    end
  end

  # Checkouts

  # A checkout from a cart: the cart's contents win over the payload, and a
  # cart converts once, so a repeat answers the checkout it already has.
  @impl true
  def create_checkout(%{"cart_id" => cart_id} = params, conn) do
    case {Store.get_checkout_for_cart(cart_id), Store.get_cart(cart_id)} do
      {checkout_id, _cart} when is_binary(checkout_id) ->
        get_checkout(checkout_id, conn)

      {nil, nil} ->
        {:error, :not_found}

      {nil, cart} ->
        state =
          cart
          |> Bazaar.Checkout.from_cart(params, stored_addresses: &Checkout.stored_addresses/1)
          |> Map.merge(%{profile_url: profile_url(conn), base_url: base_url()})

        Store.put_checkout(state)
        Store.put_checkout_for_cart(cart_id, state.id)
        {:ok, Checkout.build(state)}
    end
  end

  def create_checkout(params, conn) do
    state = Checkout.new(params, base_url: base_url(), profile_url: profile_url(conn))
    Store.put_checkout(state)
    {:ok, Checkout.build(state)}
  end

  @impl true
  def get_checkout(id, _conn) do
    case Store.get_checkout(id) do
      nil -> {:error, :not_found}
      state -> {:ok, Checkout.build(state)}
    end
  end

  @impl true
  def update_checkout(id, params, conn) do
    with {:ok, state} <- open_checkout(id) do
      state = Checkout.apply_update(state, params, profile_url: profile_url(conn))
      Store.put_checkout(state)
      {:ok, Checkout.build(state)}
    end
  end

  @impl true
  def cancel_checkout(id, _conn) do
    case Store.get_checkout(id) do
      nil ->
        {:error, :not_found}

      %{status: :completed} ->
        {:error, :invalid_state}

      state ->
        {:ok, state |> Map.put(:status, :canceled) |> Store.put_checkout() |> Checkout.build()}
    end
  end

  @impl true
  def complete_checkout(id, conn) do
    with {:ok, state} <- open_checkout(id) do
      params = conn.body_params
      state = Checkout.apply_update(state, params, profile_url: profile_url(conn))
      Store.put_checkout(state)
      checkout = Checkout.build(state)

      if Bazaar.Checkout.fulfillment_ready?(checkout) do
        authorize_and_place(state, checkout)
      else
        message =
          Bazaar.Checkout.error(
            "missing",
            "A fulfillment destination and option must be selected",
            "$.fulfillment"
          )

        {:ok, Checkout.build(state, messages: [message])}
      end
    end
  end

  # Payment failures stay in-band: the checkout comes back with an error
  # message and no order, still ready to complete with another instrument.
  defp authorize_and_place(state, checkout) do
    case Payments.authorize(state.instruments) do
      :ok ->
        place_order(state, checkout)

      {:error, reason} ->
        {:ok,
         Checkout.build(state,
           messages: [Bazaar.Checkout.error("payment_failed", reason, "$.payment")]
         )}
    end
  end

  defp place_order(state, checkout) do
    order_id = "order_" <> Checkout.uuid()
    order = Order.from_checkout(checkout, order_id, base_url() <> "/orders/" <> order_id)
    webhook_url = webhook_url(state.profile_url)
    Store.put_order(%{id: order["id"], order: order, webhook_url: webhook_url})

    state = %{state | status: :completed, order_id: order["id"]}
    Store.put_checkout(state)

    deliver(order, webhook_url)
    {:ok, Checkout.build(state)}
  end

  @impl true
  def get_order(id, _conn) do
    case Store.get_order(id) do
      nil -> {:error, :not_found}
      %{order: order} -> {:ok, order}
    end
  end

  @impl true
  def update_order(id, params, _conn) do
    with %{order: order} = record <- Store.get_order(id) || {:error, :not_found},
         {:ok, order} <- Order.apply_update(order, params) do
      Store.put_order(%{record | order: order})
      {:ok, order}
    end
  end

  @doc "Marks an order shipped and tells the platform."
  def ship_order(id) do
    case Store.get_order(id) do
      nil ->
        {:error, :not_found}

      %{order: order, webhook_url: webhook_url} = record ->
        order = Orders.ship(order)
        Store.put_order(%{record | order: order})
        deliver(order, webhook_url)
        {:ok, order}
    end
  end

  @impl true
  def cancel_order(id, _conn) do
    case Store.get_order(id) do
      nil -> {:error, :not_found}
      _record -> {:error, :invalid_state}
    end
  end

  defp open_checkout(id) do
    case Store.get_checkout(id) do
      nil -> {:error, :not_found}
      %{status: :open} = state -> {:ok, state}
      _closed -> {:error, :invalid_state}
    end
  end

  # The platform's profile says where its order events go. Without a profile
  # (no UCP-Agent header) there is nowhere to deliver.
  defp webhook_url(nil), do: nil

  defp webhook_url(profile_url) do
    case Platform.webhook_url(profile_url, http_client: &FlowerShop.Http.get/1) do
      {:ok, url} -> url
      {:error, _reason} -> nil
    end
  end

  # Signed order events, delivered off the request path with bounded retries.
  defp deliver(_order, nil), do: :ok

  defp deliver(order, url) do
    event = Webhook.event(order, url)
    signer = {signing_key(), base_url() <> "/.well-known/ucp"}

    Task.Supervisor.start_child(FlowerShop.TaskSupervisor, fn ->
      Webhook.deliver(event, http_client: &FlowerShop.Http.post/3, signer: signer)
    end)

    :ok
  end

  defp profile_url(conn), do: conn.assigns[:ucp_agent_profile]

  defp signing_key, do: Application.fetch_env!(:flower_shop, :signing_key)

  defp base_url, do: Application.fetch_env!(:flower_shop, :base_url)
end
