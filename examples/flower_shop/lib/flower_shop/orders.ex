defmodule FlowerShop.Orders do
  @moduledoc """
  Orders are stored as `%{id, order, webhook_url}`: the UCP order document plus
  where to deliver its events.
  """

  alias FlowerShop.Checkout

  @adjustment_statuses ~w(pending completed failed)

  @doc "Builds the order document for a completed checkout document."
  def from_checkout(checkout, base_url) do
    version = Bazaar.DiscoveryProfile.version()
    id = "order_" <> Checkout.uuid()

    line_items =
      Enum.map(checkout["line_items"], fn line ->
        %{
          "id" => line["id"],
          "item" => line["item"],
          "quantity" => %{"total" => line["quantity"], "fulfilled" => 0},
          "totals" => line["totals"],
          "status" => "processing"
        }
      end)

    %{
      "ucp" => %{
        "version" => version,
        "capabilities" => %{"dev.ucp.shopping.order" => [%{"version" => version}]}
      },
      "id" => id,
      "checkout_id" => checkout["id"],
      "permalink_url" => base_url <> "/orders/" <> id,
      "currency" => checkout["currency"],
      "line_items" => line_items,
      "totals" => checkout["totals"],
      "fulfillment" => %{"expectations" => expectations(checkout, line_items), "events" => []},
      "adjustments" => []
    }
    |> maybe_put("buyer", checkout["buyer"])
  end

  # One expectation per fulfillment method, described by the selected option
  # and addressed to the selected destination.
  defp expectations(checkout, line_items) do
    methods = get_in(checkout, ["fulfillment", "methods"]) || []

    methods
    |> Enum.with_index(1)
    |> Enum.map(fn {method, index} ->
      destination =
        Enum.find(method["destinations"], &(&1["id"] == method["selected_destination_id"]))

      option = selected_option(method)
      ids = method["line_item_ids"]

      %{
        "id" => "exp_#{index}",
        "line_items" =>
          for %{"id" => id, "quantity" => %{"total" => total}} <- line_items, id in ids do
            %{"id" => id, "quantity" => total}
          end,
        "method_type" => method["type"]
      }
      |> maybe_put("description", option && option["title"])
      |> maybe_put("destination", destination && Map.delete(destination, "id"))
    end)
  end

  defp selected_option(method) do
    Enum.find_value(method["groups"], fn group ->
      Enum.find(group["options"] || [], &(&1["id"] == group["selected_option_id"]))
    end)
  end

  @doc """
  Applies a `PUT /orders/:id` body: new fulfillment events and adjustments are
  appended by id. Adjustments must be a list of entries with a known status.
  """
  def apply_update(order, params) do
    with {:ok, adjustments} <- validate_adjustments(params["adjustments"]) do
      events = List.wrap(get_in(params, ["fulfillment", "events"]))

      updated =
        order
        |> update_in(["fulfillment", "events"], &append_by_id(&1, events))
        |> Map.update("adjustments", adjustments, &append_by_id(&1, adjustments))

      {:ok, updated}
    end
  end

  defp validate_adjustments(nil), do: {:ok, []}

  defp validate_adjustments(list) when is_list(list) do
    if Enum.all?(list, &(is_map(&1) and &1["status"] in @adjustment_statuses)) do
      {:ok, list}
    else
      {:error, :invalid_adjustments}
    end
  end

  defp validate_adjustments(_), do: {:error, :invalid_adjustments}

  @doc "Appends a shipped event covering every line item."
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

    update_in(order, ["fulfillment", "events"], &(&1 ++ [event]))
  end

  defp append_by_id(existing, incoming) do
    known = MapSet.new(existing, & &1["id"])
    existing ++ Enum.reject(incoming, &MapSet.member?(known, &1["id"]))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
