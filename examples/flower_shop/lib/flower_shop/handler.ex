defmodule FlowerShop.Handler do
  @moduledoc """
  The flower shop's `Bazaar.Handler`.

  `bazaar_routes` in `FlowerShopWeb.Router` serves discovery, checkouts and
  orders from these callbacks. `update_order/2` and `ship_order/1` back the
  app's own routes.
  """

  use Bazaar.Handler

  alias Bazaar.Signing.Key
  alias Bazaar.{Platform, Webhook}
  alias FlowerShop.{Catalog, Checkout, Orders, Payments, Store}

  @impl true
  def capabilities, do: [:checkout, :orders, :fulfillment, :discount, :buyer_consent]

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
    order = Orders.from_checkout(checkout, base_url())
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
         {:ok, order} <- Orders.apply_update(order, params) do
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
