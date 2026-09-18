defmodule FlowerShop.Orders do
  @moduledoc """
  What happens to an order after it is placed: shipping, as a fulfillment
  event on the UCP order document.
  """

  @doc "Records a shipped event covering every line item."
  def ship(order) do
    event = %{
      "id" => "evt_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower),
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
