defmodule FlowerShop.Shop do
  @moduledoc """
  The flower shop's facts for bazaar: what an item costs and how many are in
  stock, shipping rates and pickup at the stores, what a discount code is
  worth, the loyalty program, the payment terms, the mock payment handler,
  and the signed order event sent when an order is placed. Everything
  protocol-shaped (totals, carry-over, status, envelopes) is the library's.
  """

  use Bazaar.Shop

  alias Bazaar.{Checkout, Platform, Webhook}
  alias FlowerShop.{Catalog, Payments, Store}

  @impl true
  def base_url, do: Application.fetch_env!(:flower_shop, :base_url)

  @impl true
  def item(product_id) do
    case Catalog.product(product_id) do
      nil ->
        nil

      product ->
        %{
          item: %{
            "title" => product.title,
            "price" => product.price,
            "image_url" => product.image_url
          },
          stock: product.stock
        }
    end
  end

  # Pickup at a store is free; shipping rates depend on the destination
  # country, and standard shipping is free on orders with roses or over the
  # free-shipping threshold.
  @impl true
  def fulfillment_options(%{"type" => "business_location"}, _context) do
    [
      %{
        "id" => "in_store",
        "title" => "In-store pickup",
        "totals" => [%{"type" => "total", "amount" => 0}]
      }
    ]
  end

  def fulfillment_options(%{"address_country" => country}, %{
        line_items: lines,
        subtotal: subtotal
      }) do
    free? = Catalog.free_shipping?(subtotal, Enum.map(lines, & &1["item"]["id"]))

    country
    |> Catalog.shipping_options(free_shipping: free?)
    |> Enum.map(fn rate ->
      %{
        "id" => rate.id,
        "title" => rate.title,
        "totals" => [%{"type" => "total", "amount" => rate.price}]
      }
    end)
  end

  def fulfillment_options(_destination, _context), do: nil

  @impl true
  def pickup_locations(_context),
    do: Enum.map(Catalog.locations(), &Map.take(&1, ["id", "name", "address"]))

  @impl true
  def stored_addresses(buyer), do: Catalog.customer_addresses(buyer && buyer["email"])

  @impl true
  def discount(code, running) do
    case Catalog.discount(code) do
      nil ->
        nil

      discount ->
        %{
          "code" => Catalog.canonical_discount_code(code),
          "title" => discount.title,
          "amount" => discount_amount(discount, running)
        }
    end
  end

  defp discount_amount(%{type: :percentage, value: pct}, running), do: div(running * pct, 100)
  defp discount_amount(%{type: :fixed_amount, value: value}, running), do: min(value, running)

  @impl true
  def payment_handlers do
    handler = Catalog.payment_handler()

    %{
      handler.namespace => [%{"id" => handler.id, "version" => Bazaar.DiscoveryProfile.version()}]
    }
  end

  # The program's claim gets a membership; claims for programs the shop
  # doesn't run are ignored (the extension defines eligibility_invalid only
  # for a recognized claim that fails verification).
  @impl true
  def loyalty(%{state: state, subtotal: subtotal}) do
    if Catalog.loyalty_program() in Checkout.eligibility(state),
      do: %{
        Catalog.loyalty_program() =>
          Catalog.membership(state.buyer && state.buyer["email"], subtotal)
      },
      else: nil
  end

  @impl true
  def payment_terms(%{total: total}), do: Catalog.payment_terms(total)

  @impl true
  def authorize(instruments), do: Payments.authorize(instruments)

  # The platform's profile says where its order events go; the order's
  # webhook URL is remembered so later events (shipping) reach the same place.
  @impl true
  def order_placed(order, conn) do
    url = webhook_url(conn.assigns[:ucp_agent_profile])
    Store.put_webhook_url(order["id"], url)
    deliver(order, url)
  end

  # Every change to an order goes to the platform as the full order, at the
  # URL learned when it was placed.
  @impl true
  def order_updated(order, _conn), do: deliver(order, Store.get_webhook_url(order["id"]))

  @impl true
  def products, do: Catalog.products()

  @impl true
  def locations, do: Catalog.locations()

  @impl true
  def serves?(location, target), do: Catalog.serves?(location, target)

  @impl true
  def stocks?(location, item_ids), do: Catalog.stocks?(location, item_ids)

  @doc "Delivers a signed order event to the platform, off the request path with bounded retries."
  def deliver(_order, nil), do: :ok

  def deliver(order, url) do
    event = Webhook.event(order, url)
    signer = {signing_key(), base_url() <> "/.well-known/ucp"}

    Task.Supervisor.start_child(FlowerShop.TaskSupervisor, fn ->
      Webhook.deliver(event, http_client: &FlowerShop.Http.post/3, signer: signer)
    end)

    :ok
  end

  defp webhook_url(nil), do: nil

  defp webhook_url(profile_url) do
    case Platform.webhook_url(profile_url, http_client: &FlowerShop.Http.get/1) do
      {:ok, url} -> url
      {:error, _reason} -> nil
    end
  end

  defp signing_key, do: Application.fetch_env!(:flower_shop, :signing_key)
end
