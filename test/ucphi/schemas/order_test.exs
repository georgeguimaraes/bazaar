defmodule Ucphi.Schemas.OrderTest do
  use ExUnit.Case, async: true

  alias Ucphi.Schemas.Order

  describe "new/1" do
    test "creates valid changeset with required fields" do
      params = %{
        "id" => "order_123",
        "checkout_id" => "checkout_456",
        "permalink_url" => "https://shop.com/orders/123",
        "currency" => "USD",
        "line_items" => [
          %{
            "item" => %{"id" => "WIDGET-1", "title" => "Widget", "price" => 1999},
            "quantity" => 2
          }
        ],
        "totals" => [
          %{"type" => "subtotal", "amount" => 3998},
          %{"type" => "total", "amount" => 3998}
        ]
      }

      changeset = Order.new(params)

      assert changeset.valid?
    end

    test "returns invalid changeset when id is missing" do
      params = %{
        "checkout_id" => "checkout_456",
        "permalink_url" => "https://shop.com/orders/123",
        "line_items" => [],
        "totals" => []
      }

      changeset = Order.new(params)

      refute changeset.valid?
      assert {:id, {"can't be blank", _}} = hd(changeset.errors)
    end

    test "returns invalid changeset when checkout_id is missing" do
      params = %{
        "id" => "order_123",
        "permalink_url" => "https://shop.com/orders/123",
        "line_items" => [],
        "totals" => []
      }

      changeset = Order.new(params)

      refute changeset.valid?
      errors = Keyword.keys(changeset.errors)
      assert :checkout_id in errors
    end

    test "returns invalid changeset when permalink_url is missing" do
      params = %{
        "id" => "order_123",
        "checkout_id" => "checkout_456",
        "line_items" => [],
        "totals" => []
      }

      changeset = Order.new(params)

      refute changeset.valid?
      errors = Keyword.keys(changeset.errors)
      assert :permalink_url in errors
    end

    test "validates permalink_url format" do
      params = %{
        "id" => "order_123",
        "checkout_id" => "checkout_456",
        "permalink_url" => "not-a-url",
        "line_items" => [
          %{"item" => %{"id" => "WIDGET-1"}, "quantity" => 1}
        ],
        "totals" => [
          %{"type" => "total", "amount" => 1000}
        ]
      }

      changeset = Order.new(params)

      refute changeset.valid?
      assert {:permalink_url, {"must be a valid URL", _}} = hd(changeset.errors)
    end

    test "accepts fulfillment data" do
      params = %{
        "id" => "order_123",
        "checkout_id" => "checkout_456",
        "permalink_url" => "https://shop.com/orders/123",
        "line_items" => [
          %{"item" => %{"id" => "WIDGET-1"}, "quantity" => 1}
        ],
        "totals" => [
          %{"type" => "total", "amount" => 1000}
        ],
        "fulfillment" => %{
          "expectations" => [
            %{
              "id" => "exp_1",
              "delivery_method" => "shipping",
              "estimated_delivery_date" => "2026-01-25T00:00:00Z",
              "line_item_ids" => ["item_1"]
            }
          ],
          "events" => [
            %{
              "id" => "evt_1",
              "type" => "shipped",
              "timestamp" => "2026-01-20T14:30:00Z",
              "carrier" => "USPS",
              "tracking_number" => "1234567890"
            }
          ]
        }
      }

      changeset = Order.new(params)

      assert changeset.valid?
    end

    test "accepts adjustments" do
      params = %{
        "id" => "order_123",
        "checkout_id" => "checkout_456",
        "permalink_url" => "https://shop.com/orders/123",
        "line_items" => [
          %{"item" => %{"id" => "WIDGET-1"}, "quantity" => 1}
        ],
        "totals" => [
          %{"type" => "total", "amount" => 1000}
        ],
        "adjustments" => [
          %{
            "id" => "adj_1",
            "type" => "refund",
            "amount" => 500,
            "reason" => "Customer request",
            "timestamp" => "2026-01-22T10:00:00Z"
          }
        ]
      }

      changeset = Order.new(params)

      assert changeset.valid?
    end

    test "validates adjustment type" do
      types = Order.adjustment_type_values()

      for type <- types do
        params = %{
          "id" => "order_123",
          "checkout_id" => "checkout_456",
          "permalink_url" => "https://shop.com/orders/123",
          "line_items" => [
            %{"item" => %{"id" => "WIDGET-1"}, "quantity" => 1}
          ],
          "totals" => [
            %{"type" => "total", "amount" => 1000}
          ],
          "adjustments" => [
            %{"id" => "adj_1", "type" => to_string(type), "amount" => 500}
          ]
        }

        changeset = Order.new(params)
        assert changeset.valid?, "Expected adjustment type '#{type}' to be valid"
      end
    end

    test "validates fulfillment event type" do
      types = Order.fulfillment_event_type_values()

      for type <- types do
        params = %{
          "id" => "order_123",
          "checkout_id" => "checkout_456",
          "permalink_url" => "https://shop.com/orders/123",
          "line_items" => [
            %{"item" => %{"id" => "WIDGET-1"}, "quantity" => 1}
          ],
          "totals" => [
            %{"type" => "total", "amount" => 1000}
          ],
          "fulfillment" => %{
            "expectations" => [],
            "events" => [
              %{"id" => "evt_1", "type" => to_string(type), "timestamp" => "2026-01-20T14:30:00Z"}
            ]
          }
        }

        changeset = Order.new(params)
        assert changeset.valid?, "Expected fulfillment event type '#{type}' to be valid"
      end
    end
  end

  describe "from_checkout/3" do
    test "creates order from checkout data" do
      checkout = %{
        "id" => "checkout_abc",
        "currency" => "USD",
        "line_items" => [
          %{"item" => %{"id" => "PROD-1", "title" => "Product", "price" => 5000}, "quantity" => 2}
        ],
        "totals" => [
          %{"type" => "subtotal", "amount" => 10000},
          %{"type" => "tax", "amount" => 800},
          %{"type" => "total", "amount" => 10800}
        ]
      }

      changeset = Order.from_checkout(checkout, "order_xyz", "https://shop.com/orders/xyz")

      assert changeset.valid?
      data = Ecto.Changeset.apply_changes(changeset)
      assert data.id == "order_xyz"
      assert data.checkout_id == "checkout_abc"
      assert data.permalink_url == "https://shop.com/orders/xyz"
      assert data.currency == "USD"
    end

    test "initializes empty fulfillment and adjustments" do
      checkout = %{
        "id" => "checkout_abc",
        "currency" => "USD",
        "line_items" => [
          %{"item" => %{"id" => "PROD-1"}, "quantity" => 1}
        ],
        "totals" => [
          %{"type" => "total", "amount" => 5000}
        ]
      }

      changeset = Order.from_checkout(checkout, "order_xyz", "https://shop.com/orders/xyz")
      data = Ecto.Changeset.apply_changes(changeset)

      assert data.fulfillment.expectations == []
      assert data.fulfillment.events == []
      assert data.adjustments == []
    end

    test "sets UCP metadata" do
      checkout = %{
        "id" => "checkout_abc",
        "currency" => "USD",
        "line_items" => [],
        "totals" => []
      }

      changeset = Order.from_checkout(checkout, "order_xyz", "https://shop.com/orders/xyz")
      data = Ecto.Changeset.apply_changes(changeset)

      assert data.ucp.name == "dev.ucp.shopping.order"
      assert data.ucp.version == "2026-01-11"
    end
  end

  describe "json_schema/0" do
    test "generates valid JSON schema" do
      schema = Order.json_schema()

      assert schema["type"] == "object"
      assert is_map(schema["properties"])
      assert Map.has_key?(schema["properties"], "id")
      assert Map.has_key?(schema["properties"], "checkout_id")
      assert Map.has_key?(schema["properties"], "permalink_url")
    end

    test "includes nested schemas" do
      schema = Order.json_schema()

      assert schema["properties"]["line_items"]["type"] == "array"
      assert is_map(schema["properties"]["fulfillment"])
      assert is_map(schema["properties"]["adjustments"])
    end
  end

  describe "fields/0" do
    test "returns field definitions" do
      fields = Order.fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :id end)
      assert Enum.any?(fields, fn f -> f.name == :checkout_id end)
      assert Enum.any?(fields, fn f -> f.name == :permalink_url end)
      assert Enum.any?(fields, fn f -> f.name == :fulfillment end)
      assert Enum.any?(fields, fn f -> f.name == :adjustments end)
    end
  end

  describe "fulfillment_fields/0" do
    test "returns fulfillment field definitions" do
      fields = Order.fulfillment_fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :expectations end)
      assert Enum.any?(fields, fn f -> f.name == :events end)
    end
  end

  describe "adjustment_fields/0" do
    test "returns adjustment field definitions" do
      fields = Order.adjustment_fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :id end)
      assert Enum.any?(fields, fn f -> f.name == :type end)
      assert Enum.any?(fields, fn f -> f.name == :amount end)
    end
  end
end
