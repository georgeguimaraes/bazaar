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
  alias FlowerShop.{Catalog, Checkout, Orders, Payments, Store}

  @impl true
  def capabilities, do: [:checkout, :orders, :fulfillment, :discount, :buyer_consent, :catalog]

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
  def lookup_products(%{"ids" => ids} = params, _conn) when is_list(ids) do
    {products, unknown} = Bazaar.Catalog.lookup(Catalog.products(), ids)
    products = Bazaar.Catalog.filter(products, params["filters"])

    messages =
      for id <- unknown,
          do: %{"type" => "info", "code" => "not_found", "content" => "No product with id #{id}"}

    {:ok, %{"products" => products, "messages" => messages}}
  end

  def lookup_products(_params, _conn), do: {:error, :missing_ids}

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

  @impl true
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

      if Checkout.fulfillment_ready?(checkout) do
        authorize_and_place(state, checkout)
      else
        message =
          Checkout.error(
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
         Checkout.build(state, messages: [Checkout.error("payment_failed", reason, "$.payment")])}
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
