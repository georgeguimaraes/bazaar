defmodule FlowerShop.Orders do
  @moduledoc """
  Orders are stored as `%{id, order, webhook_url}`: the UCP order document
  (built and updated by `Bazaar.Order`) plus where to deliver its events.
  """

  alias FlowerShop.Checkout

  @doc "Records a shipped event covering every line item."
  def ship(order) do
    event = %{
      "id" => "evt_" <> Checkout.uuid(),
      "type" => "shipped",
      "occurred_at" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
      "line_items" =>
        Enum.map(order["line_items"], &%{"id" => &1["id"], "quantity" => &1["quantity"]["total"]}),
      "carrier" => "FedEx",
      "tracking_number" => "TRACK-" <> String.upcase(String.slice(order["id"], -6, 6)),
      "description" => "Shipped via FedEx"
    }

    Bazaar.Order.add_event(order, event)
  end
end
