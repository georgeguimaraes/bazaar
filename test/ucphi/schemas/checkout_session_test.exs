defmodule Ucphi.Schemas.CheckoutSessionTest do
  use ExUnit.Case, async: true

  alias Ucphi.Schemas.CheckoutSession

  describe "new/1" do
    test "creates valid changeset with required fields" do
      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"item" => %{"id" => "WIDGET-1"}, "quantity" => 2}
        ],
        "payment" => %{}
      }

      changeset = CheckoutSession.new(params)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :currency) == "USD"
    end

    test "returns invalid changeset when currency is missing" do
      params = %{
        "line_items" => [
          %{"item" => %{"id" => "ABC"}, "quantity" => 1}
        ],
        "payment" => %{}
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
      assert {:currency, {"can't be blank", _}} = hd(changeset.errors)
    end

    test "returns invalid changeset when line_items is missing" do
      params = %{"currency" => "USD", "payment" => %{}}

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
      assert {:line_items, {"can't be blank", _}} = hd(changeset.errors)
    end

    test "returns invalid changeset when payment is missing" do
      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"item" => %{"id" => "ABC"}, "quantity" => 1}
        ]
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
      assert {:payment, {"can't be blank", _}} = hd(changeset.errors)
    end

    test "returns invalid changeset when line_items is empty" do
      params = %{
        "currency" => "USD",
        "line_items" => [],
        "payment" => %{}
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
      assert {:line_items, {"should have at least %{count} item(s)", _}} = hd(changeset.errors)
    end

    test "returns invalid changeset for unsupported currency" do
      params = %{
        "currency" => "INVALID",
        "line_items" => [
          %{"item" => %{"id" => "ABC"}, "quantity" => 1}
        ],
        "payment" => %{}
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
      assert {:currency, {"is invalid", _}} = hd(changeset.errors)
    end

    test "accepts all optional fields" do
      params = %{
        "currency" => "EUR",
        "line_items" => [
          %{"item" => %{"id" => "PROD-001"}, "quantity" => 3}
        ],
        "payment" => %{"instruments" => []},
        "buyer" => %{
          "email" => "test@example.com",
          "first_name" => "John",
          "last_name" => "Doe",
          "phone_number" => "+1234567890"
        },
        "shipping_address" => %{
          "street_address" => "123 Main St",
          "address_locality" => "New York",
          "address_region" => "NY",
          "postal_code" => "10001",
          "address_country" => "US"
        },
        "totals" => [
          %{"type" => "subtotal", "amount" => 8997},
          %{"type" => "tax", "amount" => 720},
          %{"type" => "total", "amount" => 9717}
        ],
        "links" => [
          %{"type" => "privacy_policy", "url" => "https://example.com/privacy"},
          %{"type" => "terms_of_service", "url" => "https://example.com/terms"}
        ],
        "metadata" => %{"order_source" => "web"}
      }

      changeset = CheckoutSession.new(params)

      assert changeset.valid?
    end

    test "sets default status to :incomplete" do
      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"item" => %{"id" => "ABC"}, "quantity" => 1}
        ],
        "payment" => %{}
      }

      changeset = CheckoutSession.new(params)
      data = Ecto.Changeset.apply_changes(changeset)

      assert data.status == :incomplete
    end

    test "accepts all valid status values" do
      statuses = CheckoutSession.status_values()

      for status <- statuses do
        params = %{
          "currency" => "USD",
          "status" => to_string(status),
          "line_items" => [
            %{"item" => %{"id" => "ABC"}, "quantity" => 1}
          ],
          "payment" => %{}
        }

        changeset = CheckoutSession.new(params)
        assert changeset.valid?, "Expected status '#{status}' to be valid"
      end
    end
  end

  describe "validate_line_item/1" do
    test "validates required line item fields" do
      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"quantity" => 1}
        ],
        "payment" => %{}
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
    end

    test "validates item.id is required" do
      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"item" => %{}, "quantity" => 1}
        ],
        "payment" => %{}
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
    end

    test "validates quantity is at least 1" do
      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"item" => %{"id" => "ABC"}, "quantity" => 0}
        ],
        "payment" => %{}
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
    end
  end

  describe "validate_total/1" do
    test "validates totals have required fields" do
      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"item" => %{"id" => "ABC"}, "quantity" => 1}
        ],
        "payment" => %{},
        "totals" => [
          %{"type" => "subtotal"}
        ]
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
    end

    test "validates amount is non-negative" do
      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"item" => %{"id" => "ABC"}, "quantity" => 1}
        ],
        "payment" => %{},
        "totals" => [
          %{"type" => "subtotal", "amount" => -100}
        ]
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
    end

    test "accepts valid total types" do
      types = CheckoutSession.total_type_values()

      for type <- types do
        params = %{
          "currency" => "USD",
          "line_items" => [
            %{"item" => %{"id" => "ABC"}, "quantity" => 1}
          ],
          "payment" => %{},
          "totals" => [
            %{"type" => to_string(type), "amount" => 1000}
          ]
        }

        changeset = CheckoutSession.new(params)
        assert changeset.valid?, "Expected total type '#{type}' to be valid"
      end
    end
  end

  describe "validate_link/1" do
    test "validates links have required fields" do
      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"item" => %{"id" => "ABC"}, "quantity" => 1}
        ],
        "payment" => %{},
        "links" => [
          %{"type" => "privacy_policy"}
        ]
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
    end

    test "validates url format" do
      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"item" => %{"id" => "ABC"}, "quantity" => 1}
        ],
        "payment" => %{},
        "links" => [
          %{"type" => "privacy_policy", "url" => "not-a-url"}
        ]
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
    end

    test "accepts valid link types" do
      types = CheckoutSession.link_type_values()

      for type <- types do
        params = %{
          "currency" => "USD",
          "line_items" => [
            %{"item" => %{"id" => "ABC"}, "quantity" => 1}
          ],
          "payment" => %{},
          "links" => [
            %{"type" => to_string(type), "url" => "https://example.com/#{type}"}
          ]
        }

        changeset = CheckoutSession.new(params)
        assert changeset.valid?, "Expected link type '#{type}' to be valid"
      end
    end
  end

  describe "update/2" do
    test "updates existing checkout with new params" do
      existing = %{
        id: "checkout_123",
        currency: "USD",
        status: :incomplete
      }

      params = %{"status" => "ready_for_complete"}

      changeset = CheckoutSession.update(existing, params)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :status) == :ready_for_complete
    end
  end

  describe "json_schema/0" do
    test "generates valid JSON schema" do
      schema = CheckoutSession.json_schema()

      assert schema["type"] == "object"
      assert is_map(schema["properties"])
      assert Map.has_key?(schema["properties"], "currency")
      assert Map.has_key?(schema["properties"], "line_items")
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
      assert Enum.any?(fields, fn f -> f.name == :status end)
      assert Enum.any?(fields, fn f -> f.name == :totals end)
      assert Enum.any?(fields, fn f -> f.name == :links end)
    end
  end

  describe "line_item_fields/0" do
    test "returns line item field definitions" do
      fields = CheckoutSession.line_item_fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :item end)
      assert Enum.any?(fields, fn f -> f.name == :quantity end)
    end
  end

  describe "to_minor_units/1" do
    test "converts float to cents" do
      assert CheckoutSession.to_minor_units(19.99) == 1999
      assert CheckoutSession.to_minor_units(100.0) == 10000
    end

    test "converts integer to cents" do
      assert CheckoutSession.to_minor_units(20) == 2000
    end

    test "converts Decimal to cents" do
      assert CheckoutSession.to_minor_units(Decimal.new("19.99")) == 1999
    end
  end

  describe "to_major_units/1" do
    test "converts cents to dollars" do
      assert CheckoutSession.to_major_units(1999) == 19.99
      assert CheckoutSession.to_major_units(10000) == 100.0
    end
  end
end
