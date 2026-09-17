defmodule Bazaar.OrderTest do
  use ExUnit.Case, async: true

  alias Bazaar.Order

  @destination %{
    "id" => "dest_1",
    "street_address" => "123 Main St",
    "address_locality" => "Springfield",
    "address_region" => "IL",
    "postal_code" => "62704",
    "address_country" => "US"
  }

  @checkout %{
    "id" => "checkout_123",
    "currency" => "USD",
    "buyer" => %{"email" => "jane@example.com"},
    "line_items" => [
      %{
        "id" => "li_1",
        "item" => %{"id" => "PROD-1", "title" => "Widget", "price" => 1000},
        "quantity" => 2,
        "totals" => [
          %{"type" => "subtotal", "amount" => 2000},
          %{"type" => "total", "amount" => 2000}
        ]
      }
    ],
    "totals" => [
      %{"type" => "subtotal", "amount" => 2000},
      %{"type" => "fulfillment", "amount" => 500},
      %{"type" => "total", "amount" => 2500}
    ],
    "fulfillment" => %{
      "methods" => [
        %{
          "id" => "m1",
          "type" => "shipping",
          "line_item_ids" => ["li_1"],
          "destinations" => [@destination],
          "selected_destination_id" => "dest_1",
          "groups" => [
            %{
              "id" => "g1",
              "line_item_ids" => ["li_1"],
              "options" => [
                %{
                  "id" => "std",
                  "title" => "Standard Shipping",
                  "totals" => [%{"type" => "total", "amount" => 500}]
                }
              ],
              "selected_option_id" => "std"
            }
          ]
        }
      ]
    }
  }

  describe "from_checkout/3" do
    test "builds an order the UCP order schema accepts" do
      order = Order.from_checkout(@checkout, "order_456", "https://shop.example/orders/456")

      assert {:ok, _} = Bazaar.Validator.validate_order(order)
      assert order["checkout_id"] == "checkout_123"
      assert order["currency"] == "USD"
      assert order["buyer"] == %{"email" => "jane@example.com"}

      assert [
               %{
                 "id" => "li_1",
                 "quantity" => %{"total" => 2, "fulfilled" => 0},
                 "status" => "processing"
               }
             ] =
               order["line_items"]
    end

    test "describes the selected option and destination in the expectation" do
      order = Order.from_checkout(@checkout, "order_456", "https://shop.example/orders/456")

      assert [expectation] = order["fulfillment"]["expectations"]
      assert expectation["description"] == "Standard Shipping"
      assert expectation["destination"] == Map.delete(@destination, "id")
      assert expectation["line_items"] == [%{"id" => "li_1", "quantity" => 2}]
      assert expectation["method_type"] == "shipping"
    end

    test "refuses a checkout without a currency" do
      assert_raise ArgumentError, ~r/has no currency/, fn ->
        Order.from_checkout(
          %{"id" => "checkout_no_currency"},
          "order_x",
          "https://shop.example/x"
        )
      end
    end
  end

  describe "apply_update/2 and add_event/2" do
    setup do
      %{order: Order.from_checkout(@checkout, "order_456", "https://shop.example/orders/456")}
    end

    test "appends events and adjustments by id", %{order: order} do
      event = %{
        "id" => "evt_1",
        "type" => "shipped",
        "occurred_at" => "2026-09-17T00:00:00Z",
        "line_items" => [%{"id" => "li_1", "quantity" => 2}]
      }

      adjustment = %{
        "id" => "adj_1",
        "type" => "refund",
        "occurred_at" => "2026-09-17T00:00:00Z",
        "status" => "pending",
        "totals" => [%{"type" => "total", "amount" => -500}]
      }

      assert {:ok, updated} =
               Order.apply_update(order, %{
                 "fulfillment" => %{"events" => [event]},
                 "adjustments" => [adjustment]
               })

      assert {:ok, again} =
               Order.apply_update(updated, %{
                 "fulfillment" => %{"events" => [event]},
                 "adjustments" => [adjustment]
               })

      assert again["fulfillment"]["events"] == [event]
      assert again["adjustments"] == [adjustment]
      assert {:ok, _} = Bazaar.Validator.validate_order(again)
    end

    test "rejects adjustments that are not a list of entries with a known status", %{order: order} do
      assert {:error, :invalid_adjustments} =
               Order.apply_update(order, %{"adjustments" => %{"id" => "adj_1"}})

      assert {:error, :invalid_adjustments} =
               Order.apply_update(order, %{
                 "adjustments" => [%{"id" => "adj_1", "status" => "INVALID"}]
               })
    end

    test "add_event appends a fulfillment event", %{order: order} do
      event = %{
        "id" => "evt_2",
        "type" => "delivered",
        "occurred_at" => "2026-09-18T00:00:00Z",
        "line_items" => []
      }

      assert Order.add_event(order, event)["fulfillment"]["events"] == [event]
    end
  end

  describe "delegation to generated schema" do
    test "new/1 creates a changeset" do
      assert %Ecto.Changeset{} = Order.new(%{})
    end
  end
end
