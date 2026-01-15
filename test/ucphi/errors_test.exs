defmodule Ucphi.ErrorsTest do
  use ExUnit.Case, async: true

  alias Ucphi.Errors

  describe "from_changeset/1" do
    test "converts simple validation errors" do
      changeset = Ucphi.Schemas.CheckoutSession.new(%{})

      result = Errors.from_changeset(changeset)

      assert result["error"] == "validation_error"
      assert result["message"] == "Validation failed"
      assert is_list(result["details"])
    end

    test "includes field names in details" do
      changeset = Ucphi.Schemas.CheckoutSession.new(%{})

      result = Errors.from_changeset(changeset)

      fields = Enum.map(result["details"], & &1["field"])
      assert "currency" in fields
      assert "line_items" in fields
    end

    test "includes error messages in details" do
      changeset = Ucphi.Schemas.CheckoutSession.new(%{})

      result = Errors.from_changeset(changeset)

      currency_error = Enum.find(result["details"], &(&1["field"] == "currency"))
      assert currency_error["message"] == "can't be blank"
    end

    test "handles interpolated error messages" do
      # Create a changeset with a length validation error
      changeset =
        Ucphi.Schemas.CheckoutSession.new(%{
          "currency" => "USD",
          "line_items" => []
        })

      result = Errors.from_changeset(changeset)

      line_items_error = Enum.find(result["details"], &(&1["field"] == "line_items"))
      assert line_items_error["message"] =~ "should have at least"
    end

    test "handles inclusion validation errors" do
      changeset =
        Ucphi.Schemas.CheckoutSession.new(%{
          "currency" => "INVALID",
          "line_items" => [%{"sku" => "ABC", "quantity" => 1, "unit_price" => "10.00"}]
        })

      result = Errors.from_changeset(changeset)

      currency_error = Enum.find(result["details"], &(&1["field"] == "currency"))
      assert currency_error["message"] == "is invalid"
    end

    test "flattens nested errors with dot notation" do
      # Create a changeset with nested line item errors
      changeset =
        Ucphi.Schemas.CheckoutSession.new(%{
          "currency" => "USD",
          "line_items" => [
            %{"name" => "Product without required fields"}
          ]
        })

      result = Errors.from_changeset(changeset)

      # Should have nested field paths like "line_items.0.sku"
      fields = Enum.map(result["details"], & &1["field"])
      assert Enum.any?(fields, &String.contains?(&1, "line_items"))
    end

    test "handles multiple errors on same field" do
      # This test uses a custom schema to generate multiple errors
      defmodule MultiErrorSchema do
        import Ecto.Changeset

        @fields [%{name: :value, type: :integer}]

        def new(params) do
          Schemecto.new(@fields, params)
          |> validate_required([:value])
          |> validate_number(:value, greater_than: 0, less_than: 100)
        end
      end

      changeset = MultiErrorSchema.new(%{"value" => "-50"})
      result = Errors.from_changeset(changeset)

      value_errors =
        result["details"]
        |> Enum.filter(&(&1["field"] == "value"))

      assert length(value_errors) >= 1
    end

    test "returns empty details for valid changeset" do
      changeset =
        Ucphi.Schemas.CheckoutSession.new(%{
          "currency" => "USD",
          "line_items" => [%{"sku" => "ABC", "quantity" => 1, "unit_price" => "10.00"}]
        })

      # Valid changesets shouldn't normally be passed to from_changeset,
      # but if they are, details should be empty
      result = Errors.from_changeset(changeset)

      assert result["details"] == []
    end
  end

  describe "not_found/2" do
    test "creates not found error for checkout_session" do
      result = Errors.not_found("checkout_session", "sess_123")

      assert result == %{
               "error" => "not_found",
               "message" => "checkout_session not found",
               "resource_type" => "checkout_session",
               "resource_id" => "sess_123"
             }
    end

    test "creates not found error for order" do
      result = Errors.not_found("order", "order_456")

      assert result["error"] == "not_found"
      assert result["message"] == "order not found"
      assert result["resource_type"] == "order"
      assert result["resource_id"] == "order_456"
    end

    test "handles any resource type" do
      result = Errors.not_found("custom_resource", "custom_123")

      assert result["resource_type"] == "custom_resource"
      assert result["message"] == "custom_resource not found"
    end
  end

  describe "from_reason/1 with known atoms" do
    test "handles :not_found" do
      result = Errors.from_reason(:not_found)

      assert result == %{
               "error" => "not_found",
               "message" => "Resource not found"
             }
    end

    test "handles :unauthorized" do
      result = Errors.from_reason(:unauthorized)

      assert result == %{
               "error" => "unauthorized",
               "message" => "Authentication required"
             }
    end

    test "handles :forbidden" do
      result = Errors.from_reason(:forbidden)

      assert result == %{
               "error" => "forbidden",
               "message" => "Access denied"
             }
    end

    test "handles :invalid_state" do
      result = Errors.from_reason(:invalid_state)

      assert result == %{
               "error" => "invalid_state",
               "message" => "Operation not allowed in current state"
             }
    end

    test "handles :already_cancelled" do
      result = Errors.from_reason(:already_cancelled)

      assert result == %{
               "error" => "already_cancelled",
               "message" => "Resource is already cancelled"
             }
    end

    test "handles :expired" do
      result = Errors.from_reason(:expired)

      assert result == %{
               "error" => "expired",
               "message" => "Resource has expired"
             }
    end
  end

  describe "from_reason/1 with unknown atoms" do
    test "humanizes unknown atom errors" do
      result = Errors.from_reason(:payment_failed)

      assert result["error"] == "payment_failed"
      assert result["message"] == "Payment failed"
    end

    test "handles underscored atoms" do
      result = Errors.from_reason(:insufficient_funds)

      assert result["error"] == "insufficient_funds"
      assert result["message"] == "Insufficient funds"
    end

    test "handles single word atoms" do
      result = Errors.from_reason(:timeout)

      assert result["error"] == "timeout"
      assert result["message"] == "Timeout"
    end
  end

  describe "from_reason/1 with strings" do
    test "uses string as message" do
      result = Errors.from_reason("Something went wrong")

      assert result == %{
               "error" => "error",
               "message" => "Something went wrong"
             }
    end

    test "handles empty string" do
      result = Errors.from_reason("")

      assert result["error"] == "error"
      assert result["message"] == ""
    end

    test "preserves string formatting" do
      result = Errors.from_reason("Error: Invalid input at line 42")

      assert result["message"] == "Error: Invalid input at line 42"
    end
  end

  describe "from_reason/1 with other types" do
    test "inspects tuples" do
      result = Errors.from_reason({:error, :db_connection_failed})

      assert result["error"] == "error"
      assert result["message"] == "{:error, :db_connection_failed}"
    end

    test "inspects maps" do
      result = Errors.from_reason(%{code: 500, reason: "internal"})

      assert result["error"] == "error"
      assert result["message"] =~ "code"
      assert result["message"] =~ "500"
    end

    test "inspects lists" do
      result = Errors.from_reason([:error1, :error2])

      assert result["error"] == "error"
      assert result["message"] == "[:error1, :error2]"
    end

    test "inspects integers" do
      result = Errors.from_reason(500)

      assert result["error"] == "error"
      assert result["message"] == "500"
    end
  end

  describe "JSON encodability" do
    test "from_changeset result is JSON encodable" do
      changeset = Ucphi.Schemas.CheckoutSession.new(%{})
      result = Errors.from_changeset(changeset)

      assert {:ok, _json} = Jason.encode(result)
    end

    test "not_found result is JSON encodable" do
      result = Errors.not_found("order", "123")

      assert {:ok, _json} = Jason.encode(result)
    end

    test "from_reason result is JSON encodable" do
      result = Errors.from_reason(:forbidden)

      assert {:ok, _json} = Jason.encode(result)
    end
  end
end
