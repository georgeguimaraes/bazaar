defmodule Bazaar.Order do
  @moduledoc """
  Order documents: building one from a completed checkout, applying the
  updates a platform sends, and recording fulfillment events.

  Schema validation is delegated to the generated
  `Bazaar.Schemas.Shopping.OrderResp`.

      order = Bazaar.Order.from_checkout(checkout, "order_123", "https://shop.example/orders/123")
      {:ok, order} = Bazaar.Order.apply_update(order, params)
      order = Bazaar.Order.add_event(order, shipped_event)
  """

  alias Bazaar.Schemas.Shopping.OrderResp, as: OrderSchema

  # Delegate schema functions to the generated module
  defdelegate new(params \\ %{}), to: OrderSchema
  defdelegate changeset(params), to: OrderSchema

  @adjustment_statuses ~w(pending completed failed)

  @doc """
  Builds the order document for a completed checkout document.

  Line items become order line items (`quantity: %{total, fulfilled}`,
  `status: "processing"`), totals and buyer are carried over, and one
  fulfillment expectation per method describes the selected option and
  destination. UCP orders require a currency, so the checkout must carry one.
  """
  def from_checkout(%{"currency" => currency} = checkout, order_id, permalink_url)
      when is_binary(currency) do
    version = Bazaar.DiscoveryProfile.version()
    line_items = Enum.map(checkout["line_items"] || [], &order_line_item/1)

    %{
      "ucp" => %{
        "version" => version,
        "capabilities" => %{"dev.ucp.shopping.order" => [%{"version" => version}]}
      },
      "id" => order_id,
      "checkout_id" => checkout["id"],
      "permalink_url" => permalink_url,
      "currency" => currency,
      "line_items" => line_items,
      "totals" => checkout["totals"] || [],
      "fulfillment" => %{"expectations" => expectations(checkout, line_items), "events" => []},
      "adjustments" => []
    }
    |> maybe_put("buyer", checkout["buyer"])
    |> maybe_put("payment", accepted_term(checkout["payment"]))
  end

  def from_checkout(checkout, _order_id, _permalink_url) do
    raise ArgumentError,
          "checkout #{inspect(checkout["id"])} has no currency, which UCP orders require"
  end

  # The payment terms extension carries the accepted term onto the order.
  defp accepted_term(%{"terms" => terms, "selected_term_id" => id}) when is_list(terms) do
    case Enum.find(terms, &(&1["id"] == id)) do
      nil -> nil
      term -> %{"accepted_term" => term}
    end
  end

  defp accepted_term(_payment), do: nil

  defp order_line_item(line) do
    %{
      "id" => line["id"],
      "item" => line["item"],
      "quantity" => %{"total" => line["quantity"], "fulfilled" => 0},
      "totals" => line["totals"] || [],
      "status" => "processing"
    }
  end

  # One expectation per fulfillment method, described by the selected option
  # and addressed to the selected destination.
  defp expectations(checkout, line_items) do
    methods = get_in(checkout, ["fulfillment", "methods"]) || []

    methods
    |> Enum.with_index(1)
    |> Enum.map(fn {method, index} ->
      destinations = method["destinations"] || []
      destination = Enum.find(destinations, &(&1["id"] == method["selected_destination_id"]))
      option = selected_option(method)
      ids = method["line_item_ids"] || Enum.map(line_items, & &1["id"])

      %{
        "id" => "exp_#{index}",
        "line_items" =>
          for %{"id" => id, "quantity" => %{"total" => total}} <- line_items, id in ids do
            %{"id" => id, "quantity" => total}
          end,
        "method_type" => method["type"] || "shipping"
      }
      |> maybe_put("description", option && option["title"])
      |> maybe_put("destination", destination && Map.delete(destination, "id"))
    end)
  end

  defp selected_option(method) do
    Enum.find_value(method["groups"] || [], fn group ->
      Enum.find(group["options"] || [], &(&1["id"] == group["selected_option_id"]))
    end)
  end

  @doc """
  Applies an update a platform sent for an order: new `fulfillment.events`
  and `adjustments` are appended by id. Adjustments must be a list of entries
  with a status of `pending`, `completed` or `failed`, otherwise
  `{:error, :invalid_adjustments}`.
  """
  def apply_update(order, params) do
    with {:ok, adjustments} <- validate_adjustments(params["adjustments"]) do
      events = List.wrap(get_in(params, ["fulfillment", "events"]))

      updated =
        order
        |> update_in(["fulfillment", "events"], &append_by_id(&1 || [], events))
        |> Map.update("adjustments", adjustments, &append_by_id(&1 || [], adjustments))

      {:ok, updated}
    end
  end

  @doc "Appends a fulfillment event (shipped, delivered, ...) to an order."
  def add_event(order, event) when is_map(event) do
    update_in(order, ["fulfillment", "events"], &((&1 || []) ++ [event]))
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

  defp append_by_id(existing, incoming) do
    known = MapSet.new(existing, & &1["id"])
    existing ++ Enum.reject(incoming, &MapSet.member?(known, &1["id"]))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
