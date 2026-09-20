defmodule FlowerShop.Handler do
  @moduledoc """
  The flower shop's `Bazaar.Handler`: every capability answered from
  `FlowerShop.Shop` and `FlowerShop.Store` by the library's defaults.
  `ship_order/1` backs the app's own simulate-shipping route.
  """

  use Bazaar.Handler, shop: FlowerShop.Shop, store: FlowerShop.Store

  alias Bazaar.Signing.Key
  alias FlowerShop.{Catalog, Orders, Shop, Store}

  @impl true
  def capabilities,
    do: [
      :checkout,
      :orders,
      :fulfillment,
      :discount,
      :buyer_consent,
      :catalog,
      :cart,
      :location,
      :loyalty,
      :payment_terms
    ]

  @impl true
  def business_profile do
    handler = Catalog.payment_handler()

    %{
      "name" => "Flower Shop",
      "description" => "Bouquets, pots and orchids, shipped or picked up",
      "support_email" => "hello@flowershop.example",
      "payment_handlers" => [%{"name" => handler.namespace, "id" => handler.id, "config" => %{}}],
      "keys" => [Key.public_jwk(Application.fetch_env!(:flower_shop, :signing_key))]
    }
  end

  @doc "Marks an order shipped and tells the platform."
  def ship_order(id) do
    case Store.get_order(id) do
      nil ->
        {:error, :not_found}

      order ->
        order = order |> Orders.ship() |> Store.put_order()
        Bazaar.Webhook.deliver_order(order, Shop, Store.get_platform(id))
        {:ok, order}
    end
  end
end
