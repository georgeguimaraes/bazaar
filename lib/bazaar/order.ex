defmodule Bazaar.Order do
  @moduledoc """
  Business logic helpers for UCP Orders.

  This module provides utilities for working with order data,
  delegating schema validation to the generated `Bazaar.Schemas.Shopping.OrderResp`.
  """

  alias Bazaar.Schemas.Shopping.OrderResp, as: OrderSchema

  # Delegate schema functions to the generated module
  defdelegate new(params \\ %{}), to: OrderSchema
  defdelegate changeset(params), to: OrderSchema

  @doc """
  Creates an order from a completed checkout session.

  UCP orders require a currency, so the checkout must carry one.

  ## Example

      order_params = Bazaar.Order.from_checkout(checkout_data, "order-123", "https://shop.com/orders/123")
  """
  def from_checkout(%{"currency" => currency} = checkout, order_id, permalink_url)
      when is_binary(currency) do
    version = Bazaar.DiscoveryProfile.version()

    %{
      "id" => order_id,
      "checkout_id" => checkout["id"],
      "permalink_url" => permalink_url,
      "currency" => currency,
      "line_items" => checkout["line_items"] || [],
      "totals" => checkout["totals"] || [],
      "fulfillment" => %{
        "expectations" => [],
        "events" => []
      },
      "adjustments" => [],
      "ucp" => %{
        "version" => version,
        "capabilities" => %{"dev.ucp.shopping.order" => [%{"version" => version}]}
      }
    }
  end

  def from_checkout(checkout, _order_id, _permalink_url) do
    raise ArgumentError,
          "checkout #{inspect(checkout["id"])} has no currency, which UCP orders require"
  end
end
