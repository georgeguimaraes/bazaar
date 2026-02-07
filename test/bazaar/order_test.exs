defmodule Bazaar.OrderTest do
  use ExUnit.Case, async: true

  alias Bazaar.Order

  describe "from_checkout/3" do
    test "creates order params from checkout data" do
      checkout = %{
        "id" => "checkout_123",
        "currency" => "USD",
        "line_items" => [
          %{"item" => %{"id" => "PROD-1"}, "quantity" => 2}
        ],
        "totals" => [
          %{"type" => "subtotal", "amount" => 2000},
          %{"type" => "total", "amount" => 2000}
        ]
      }

      result = Order.from_checkout(checkout, "order_456", "https://shop.com/orders/456")

      assert result["id"] == "order_456"
      assert result["checkout_id"] == "checkout_123"
      assert result["permalink_url"] == "https://shop.com/orders/456"
      assert result["currency"] == "USD"
      assert result["line_items"] == checkout["line_items"]
      assert result["totals"] == checkout["totals"]
      assert result["fulfillment"] == %{"expectations" => [], "events" => []}
      assert result["adjustments"] == []
      assert result["ucp"]["name"] == "dev.ucp.shopping.order"
      assert result["ucp"]["version"] == "2026-01-23"
    end

    test "handles missing optional fields" do
      checkout = %{
        "id" => "checkout_minimal"
      }

      result = Order.from_checkout(checkout, "order_min", "https://shop.com/orders/min")

      assert result["line_items"] == []
      assert result["totals"] == []
    end
  end

  describe "delegation to generated schema" do
    test "embedded_schema has expected fields" do
      alias Bazaar.Schemas.Shopping.Order, as: OrderSchema

      field_names = OrderSchema.__schema__(:fields)

      assert :id in field_names
      assert :checkout_id in field_names
    end

    test "new/1 creates a changeset" do
      changeset = Order.new(%{})

      assert %Ecto.Changeset{} = changeset
    end
  end
end
