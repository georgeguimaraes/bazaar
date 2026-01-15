defmodule Ucphi.Schemas.CheckoutSessionTest do
  use ExUnit.Case, async: true

  alias Ucphi.Schemas.CheckoutSession

  describe "new/1" do
    test "creates valid changeset with required fields" do
      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"sku" => "WIDGET-1", "quantity" => 2, "unit_price" => "19.99"}
        ]
      }

      changeset = CheckoutSession.new(params)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :currency) == "USD"
    end

    test "returns invalid changeset when currency is missing" do
      params = %{
        "line_items" => [
          %{"sku" => "ABC", "quantity" => 1, "unit_price" => "10.00"}
        ]
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
      assert {:currency, {"can't be blank", _}} = hd(changeset.errors)
    end

    test "returns invalid changeset when line_items is missing" do
      params = %{"currency" => "USD"}

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
      assert {:line_items, {"can't be blank", _}} = hd(changeset.errors)
    end

    test "returns invalid changeset when line_items is empty" do
      params = %{
        "currency" => "USD",
        "line_items" => []
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
      assert {:line_items, {"should have at least %{count} item(s)", _}} = hd(changeset.errors)
    end

    test "returns invalid changeset for unsupported currency" do
      params = %{
        "currency" => "INVALID",
        "line_items" => [
          %{"sku" => "ABC", "quantity" => 1, "unit_price" => "10.00"}
        ]
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
      assert {:currency, {"is invalid", _}} = hd(changeset.errors)
    end

    test "accepts all optional fields" do
      params = %{
        "currency" => "EUR",
        "line_items" => [
          %{
            "sku" => "PROD-001",
            "name" => "Test Product",
            "description" => "A great product",
            "quantity" => 3,
            "unit_price" => "29.99",
            "image_url" => "https://example.com/image.jpg"
          }
        ],
        "buyer" => %{
          "email" => "test@example.com",
          "name" => "John Doe",
          "phone" => "+1234567890"
        },
        "shipping_address" => %{
          "line1" => "123 Main St",
          "city" => "New York",
          "state" => "NY",
          "postal_code" => "10001",
          "country" => "US"
        },
        "metadata" => %{"order_source" => "web"}
      }

      changeset = CheckoutSession.new(params)

      assert changeset.valid?
    end

    test "casts decimal fields correctly" do
      params = %{
        "currency" => "USD",
        "subtotal" => "99.99",
        "tax" => "8.50",
        "shipping" => "5.00",
        "total" => "113.49",
        "line_items" => [
          %{"sku" => "ABC", "quantity" => 1, "unit_price" => "99.99"}
        ]
      }

      changeset = CheckoutSession.new(params)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :subtotal) == Decimal.new("99.99")
      assert Ecto.Changeset.get_change(changeset, :total) == Decimal.new("113.49")
    end

    test "sets default status to :open" do
      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"sku" => "ABC", "quantity" => 1, "unit_price" => "10.00"}
        ]
      }

      changeset = CheckoutSession.new(params)
      data = Ecto.Changeset.apply_changes(changeset)

      assert data.status == :open
    end
  end

  describe "validate_line_item/1" do
    test "validates required line item fields" do
      # Line item without required fields
      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"name" => "Product without SKU"}
        ]
      }

      changeset = CheckoutSession.new(params)

      # The nested validation should fail
      refute changeset.valid?
    end

    test "validates quantity is greater than 0" do
      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"sku" => "ABC", "quantity" => 0, "unit_price" => "10.00"}
        ]
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
    end

    test "validates unit_price is non-negative" do
      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"sku" => "ABC", "quantity" => 1, "unit_price" => "-5.00"}
        ]
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
    end
  end

  describe "update/2" do
    test "updates existing checkout with new params" do
      existing = %{
        id: "checkout_123",
        currency: "USD",
        status: :open,
        total: Decimal.new("100.00")
      }

      params = %{"total" => "150.00"}

      changeset = CheckoutSession.update(existing, params)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :total) == Decimal.new("150.00")
    end
  end

  describe "json_schema/0" do
    test "generates valid JSON schema" do
      schema = CheckoutSession.json_schema()

      assert schema["type"] == "object"
      assert is_map(schema["properties"])
      assert Map.has_key?(schema["properties"], "currency")
      assert Map.has_key?(schema["properties"], "line_items")
      assert Map.has_key?(schema["properties"], "total")
    end

    test "includes nested schemas for line_items" do
      schema = CheckoutSession.json_schema()

      assert schema["properties"]["line_items"]["type"] == "array"
      assert is_map(schema["properties"]["line_items"]["items"])
    end
  end

  describe "fields/0" do
    test "returns field definitions" do
      fields = CheckoutSession.fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :currency end)
      assert Enum.any?(fields, fn f -> f.name == :line_items end)
    end
  end

  describe "line_item_fields/0" do
    test "returns line item field definitions" do
      fields = CheckoutSession.line_item_fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :sku end)
      assert Enum.any?(fields, fn f -> f.name == :quantity end)
      assert Enum.any?(fields, fn f -> f.name == :unit_price end)
    end
  end
end
