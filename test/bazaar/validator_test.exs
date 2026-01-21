defmodule Bazaar.ValidatorTest do
  use ExUnit.Case, async: true

  alias Bazaar.Validator

  describe "available_schemas/0" do
    test "returns list of available schemas" do
      schemas = Validator.available_schemas()

      assert :checkout in schemas
      assert :order in schemas
    end
  end

  describe "get_schema/1" do
    test "returns checkout schema" do
      assert {:ok, schema} = Validator.get_schema(:checkout)

      assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
      assert schema["title"] == "Checkout Response"
      assert is_list(schema["required"])
    end

    test "returns order schema" do
      assert {:ok, schema} = Validator.get_schema(:order)

      assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
      assert is_list(schema["required"])
    end
  end

  describe "validate_checkout/1" do
    test "validates a complete checkout response" do
      checkout = %{
        "ucp" => %{
          "version" => "2026-01-11",
          "capabilities" => [
            %{"name" => "dev.ucp.shopping.checkout", "version" => "2026-01-11"}
          ]
        },
        "id" => "checkout_123",
        "status" => "incomplete",
        "currency" => "USD",
        "line_items" => [
          %{
            "id" => "li_1",
            "item" => %{"id" => "PROD-1", "title" => "Widget", "price" => 1000},
            "quantity" => 1,
            "totals" => [
              %{"type" => "subtotal", "amount" => 1000}
            ]
          }
        ],
        "totals" => [
          %{"type" => "subtotal", "amount" => 1000},
          %{"type" => "total", "amount" => 1000}
        ],
        "links" => [
          %{"type" => "privacy_policy", "url" => "https://example.com/privacy"},
          %{"type" => "terms_of_service", "url" => "https://example.com/terms"}
        ],
        "payment" => %{
          "handlers" => []
        }
      }

      result = Validator.validate_checkout(checkout)

      case result do
        {:ok, _validated} ->
          assert true

        {:error, errors} ->
          flunk("Expected valid checkout but got errors: #{inspect(errors)}")
      end
    end

    test "returns errors for missing required fields" do
      checkout = %{
        "id" => "checkout_123"
      }

      assert {:error, errors} = Validator.validate_checkout(checkout)
      assert is_list(errors) or is_map(errors)
    end

    test "returns errors for invalid status" do
      checkout = %{
        "ucp" => %{
          "name" => "dev.ucp.shopping.checkout",
          "version" => "2026-01-11"
        },
        "id" => "checkout_123",
        "status" => "invalid_status",
        "currency" => "USD",
        "line_items" => [],
        "totals" => [],
        "links" => %{
          "privacy_policy" => "https://example.com/privacy",
          "terms_of_service" => "https://example.com/terms"
        },
        "payment" => %{}
      }

      assert {:error, _errors} = Validator.validate_checkout(checkout)
    end
  end

  describe "validate_order/1" do
    test "validates a complete order response" do
      order = %{
        "ucp" => %{
          "version" => "2026-01-11",
          "capabilities" => [
            %{"name" => "dev.ucp.shopping.order", "version" => "2026-01-11"}
          ]
        },
        "id" => "order_123",
        "checkout_id" => "checkout_456",
        "permalink_url" => "https://shop.example.com/orders/123",
        "line_items" => [
          %{
            "id" => "li_1",
            "item" => %{"id" => "PROD-1", "title" => "Widget", "price" => 1000},
            "quantity" => %{"total" => 1, "fulfilled" => 0},
            "totals" => [%{"type" => "subtotal", "amount" => 1000}],
            "status" => "processing"
          }
        ],
        "fulfillment" => %{
          "expectations" => [],
          "events" => []
        },
        "totals" => [
          %{"type" => "total", "amount" => 1000}
        ]
      }

      result = Validator.validate_order(order)

      case result do
        {:ok, _validated} ->
          assert true

        {:error, errors} ->
          flunk("Expected valid order but got errors: #{inspect(errors)}")
      end
    end

    test "returns errors for missing required fields" do
      order = %{
        "id" => "order_123"
      }

      assert {:error, errors} = Validator.validate_order(order)
      assert is_list(errors) or is_map(errors)
    end
  end

  describe "validate/2" do
    test "validates with :checkout schema" do
      data = %{"id" => "test"}
      assert {:error, _} = Validator.validate(data, :checkout)
    end

    test "validates with :order schema" do
      data = %{"id" => "test"}
      assert {:error, _} = Validator.validate(data, :order)
    end
  end
end
