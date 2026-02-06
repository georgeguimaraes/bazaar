defmodule Bazaar.ValidatorTest do
  use ExUnit.Case, async: true

  alias Bazaar.Validator

  describe "available_schemas/0" do
    test "returns schemas grouped by protocol" do
      schemas = Validator.available_schemas()

      assert :checkout in schemas.ucp
      assert :order in schemas.ucp
      assert :openai_product_feed in schemas.acp
      assert :checkout_session in schemas.acp
      assert :delegate_payment_req in schemas.acp
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
          "version" => "2026-01-23",
          "capabilities" => %{
            "dev.ucp.shopping.checkout" => [%{"version" => "2026-01-23"}]
          },
          "payment_handlers" => %{
            "com.stripe" => [%{"version" => "2026-01-23", "id" => "stripe_1"}]
          }
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
          "version" => "2026-01-23"
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
          "version" => "2026-01-23",
          "capabilities" => %{
            "dev.ucp.shopping.order" => [%{"version" => "2026-01-23"}]
          }
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

  describe "ACP checkout session validation" do
    test "validates a valid ACP checkout session" do
      session = %{
        "id" => "cs_123",
        "status" => "not_ready_for_payment",
        "currency" => "USD",
        "line_items" => [
          %{
            "id" => "li_1",
            "item" => %{"id" => "PROD-1", "quantity" => 1},
            "base_amount" => 1000,
            "discount" => 0,
            "subtotal" => 1000,
            "tax" => 80,
            "total" => 1080
          }
        ],
        "totals" => [%{"type" => "total", "display_text" => "Total", "amount" => 1080}],
        "fulfillment_options" => [],
        "messages" => [],
        "links" => []
      }

      assert {:ok, _} = Validator.validate(session, :checkout_session)
    end

    test "rejects invalid ACP checkout session" do
      assert {:error, _} = Validator.validate(%{}, :checkout_session)
    end
  end

  describe "ACP checkout request validation" do
    test "validates a valid create request" do
      req = %{
        "items" => [%{"id" => "PROD-1", "quantity" => 2}]
      }

      assert {:ok, _} = Validator.validate(req, :checkout_create_req)
    end

    test "rejects create request without items" do
      assert {:error, _} = Validator.validate(%{}, :checkout_create_req)
    end

    test "validates a valid complete request" do
      req = %{
        "payment_data" => %{
          "token" => "tok_123",
          "provider" => "stripe"
        }
      }

      assert {:ok, _} = Validator.validate(req, :checkout_complete_req)
    end
  end

  describe "ACP delegate payment validation" do
    test "validates a valid delegate payment request" do
      req = %{
        "payment_method" => %{
          "type" => "card",
          "card_number_type" => "network_token",
          "number" => "4111111111111111",
          "display_card_funding_type" => "credit",
          "metadata" => %{}
        },
        "allowance" => %{
          "reason" => "one_time",
          "max_amount" => 2000,
          "currency" => "usd",
          "checkout_session_id" => "cs_123",
          "merchant_id" => "merch_1",
          "expires_at" => "2026-12-31T23:59:59Z"
        },
        "risk_signals" => [%{"type" => "card_testing", "score" => 10, "action" => "authorized"}],
        "metadata" => %{}
      }

      assert {:ok, _} = Validator.validate(req, :delegate_payment_req)
    end

    test "rejects invalid delegate payment request" do
      assert {:error, _} = Validator.validate(%{}, :delegate_payment_req)
    end

    test "validates a valid delegate payment response" do
      resp = %{
        "id" => "vt_abc123",
        "created" => "2026-01-15T10:30:00Z",
        "metadata" => %{}
      }

      assert {:ok, _} = Validator.validate(resp, :delegate_payment_resp)
    end
  end
end
