defmodule Ucphi.Schemas.OrderTest do
  use ExUnit.Case, async: true

  alias Ucphi.Schemas.Order

  describe "new/1" do
    test "creates valid changeset with required fields" do
      params = %{
        "id" => "order_123",
        "status" => "pending",
        "currency" => "USD",
        "total" => "99.99",
        "line_items" => [
          %{"sku" => "PROD-1", "quantity" => 1, "unit_price" => "99.99"}
        ]
      }

      changeset = Order.new(params)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :id) == "order_123"
      assert Ecto.Changeset.get_change(changeset, :status) == :pending
    end

    test "returns invalid changeset when id is missing" do
      params = %{
        "status" => "pending",
        "currency" => "USD",
        "total" => "99.99",
        "line_items" => [
          %{"sku" => "ABC", "quantity" => 1, "unit_price" => "99.99"}
        ]
      }

      changeset = Order.new(params)

      refute changeset.valid?
      assert {:id, {"can't be blank", _}} = hd(changeset.errors)
    end

    test "returns invalid changeset when status is missing" do
      params = %{
        "id" => "order_123",
        "currency" => "USD",
        "total" => "99.99",
        "line_items" => [
          %{"sku" => "ABC", "quantity" => 1, "unit_price" => "99.99"}
        ]
      }

      changeset = Order.new(params)

      refute changeset.valid?
      assert {:status, {"can't be blank", _}} = hd(changeset.errors)
    end

    test "accepts all valid status values" do
      statuses = ~w(pending confirmed processing shipped delivered cancelled refunded)

      for status <- statuses do
        params = %{
          "id" => "order_#{status}",
          "status" => status,
          "currency" => "USD",
          "total" => "50.00",
          "line_items" => [
            %{"sku" => "ABC", "quantity" => 1, "unit_price" => "50.00"}
          ]
        }

        changeset = Order.new(params)
        assert changeset.valid?, "Expected status '#{status}' to be valid"
      end
    end

    test "accepts fulfillment_status values" do
      params = %{
        "id" => "order_123",
        "status" => "confirmed",
        "fulfillment_status" => "partially_fulfilled",
        "currency" => "USD",
        "total" => "99.99",
        "line_items" => [
          %{"sku" => "ABC", "quantity" => 1, "unit_price" => "99.99"}
        ]
      }

      changeset = Order.new(params)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :fulfillment_status) == :partially_fulfilled
    end

    test "accepts payment_status values" do
      params = %{
        "id" => "order_123",
        "status" => "confirmed",
        "payment_status" => "captured",
        "currency" => "USD",
        "total" => "99.99",
        "line_items" => [
          %{"sku" => "ABC", "quantity" => 1, "unit_price" => "99.99"}
        ]
      }

      changeset = Order.new(params)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :payment_status) == :captured
    end

    test "accepts shipments array" do
      params = %{
        "id" => "order_123",
        "status" => "shipped",
        "currency" => "USD",
        "total" => "99.99",
        "line_items" => [
          %{"sku" => "ABC", "quantity" => 1, "unit_price" => "99.99"}
        ],
        "shipments" => [
          %{
            "id" => "ship_001",
            "carrier" => "UPS",
            "tracking_number" => "1Z999AA10123456784",
            "tracking_url" => "https://ups.com/track/1Z999AA10123456784",
            "status" => "in_transit"
          }
        ]
      }

      changeset = Order.new(params)

      assert changeset.valid?
    end

    test "accepts buyer and address information" do
      params = %{
        "id" => "order_123",
        "status" => "pending",
        "currency" => "USD",
        "total" => "99.99",
        "line_items" => [
          %{"sku" => "ABC", "quantity" => 1, "unit_price" => "99.99"}
        ],
        "buyer" => %{
          "email" => "buyer@example.com",
          "name" => "Jane Smith"
        },
        "shipping_address" => %{
          "line1" => "456 Oak Ave",
          "city" => "Los Angeles",
          "state" => "CA",
          "postal_code" => "90001",
          "country" => "US"
        }
      }

      changeset = Order.new(params)

      assert changeset.valid?
    end
  end

  describe "from_checkout/2" do
    test "creates order from checkout data" do
      checkout = %{
        id: "checkout_abc",
        currency: "USD",
        subtotal: Decimal.new("100.00"),
        tax: Decimal.new("8.00"),
        shipping: Decimal.new("5.00"),
        total: Decimal.new("113.00"),
        line_items: [
          %{sku: "PROD-1", quantity: 2, unit_price: Decimal.new("50.00")}
        ],
        buyer: %{email: "test@example.com", name: "Test User"},
        shipping_address: %{line1: "123 Main St", city: "NYC", country: "US"},
        billing_address: nil,
        metadata: %{"source" => "web"}
      }

      changeset = Order.from_checkout(checkout, "order_xyz")

      assert changeset.valid?

      order = Ecto.Changeset.apply_changes(changeset)

      assert order.id == "order_xyz"
      assert order.checkout_session_id == "checkout_abc"
      assert order.status == :pending
      assert order.fulfillment_status == :unfulfilled
      assert order.payment_status == :pending
      assert order.currency == "USD"
      assert order.total == Decimal.new("113.00")
    end
  end

  describe "json_schema/0" do
    test "generates valid JSON schema" do
      schema = Order.json_schema()

      assert schema["type"] == "object"
      assert is_map(schema["properties"])
      assert Map.has_key?(schema["properties"], "id")
      assert Map.has_key?(schema["properties"], "status")
      assert Map.has_key?(schema["properties"], "line_items")
      assert Map.has_key?(schema["properties"], "shipments")
    end

    test "includes enum values for status" do
      schema = Order.json_schema()

      assert is_list(schema["properties"]["status"]["enum"])
      assert "pending" in schema["properties"]["status"]["enum"]
      assert "shipped" in schema["properties"]["status"]["enum"]
    end
  end

  describe "fields/0" do
    test "returns field definitions" do
      fields = Order.fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :id end)
      assert Enum.any?(fields, fn f -> f.name == :status end)
      assert Enum.any?(fields, fn f -> f.name == :shipments end)
    end
  end

  describe "shipment_fields/0" do
    test "returns shipment field definitions" do
      fields = Order.shipment_fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :carrier end)
      assert Enum.any?(fields, fn f -> f.name == :tracking_number end)
    end
  end
end
