defmodule Bazaar.Order do
  @moduledoc """
  Business logic helpers for UCP Orders.

  This module provides utilities for working with order data,
  delegating schema validation to the generated `Bazaar.Schemas.Shopping.Order`.
  """

  alias Bazaar.Schemas.Shopping.Order, as: OrderSchema

  # Delegate schema functions to the generated module
  defdelegate new(params \\ %{}), to: OrderSchema
  defdelegate changeset(params), to: OrderSchema

  @doc """
  Creates an order from a completed checkout session.

  ## Example

      order_params = Bazaar.Order.from_checkout(checkout_data, "order-123", "https://shop.com/orders/123")
  """
  def from_checkout(checkout, order_id, permalink_url) do
    %{
      "id" => order_id,
      "checkout_id" => checkout[:id] || checkout["id"],
      "permalink_url" => permalink_url,
      "currency" => checkout[:currency] || checkout["currency"],
      "line_items" => checkout[:line_items] || checkout["line_items"] || [],
      "totals" => checkout[:totals] || checkout["totals"] || [],
      "fulfillment" => %{
        "expectations" => [],
        "events" => []
      },
      "adjustments" => [],
      "ucp" => %{
        "name" => "dev.ucp.shopping.order",
        "version" => "2026-01-11"
      }
    }
  end
end
