defmodule Bazaar.ErrorsTest do
  use ExUnit.Case, async: true

  alias Bazaar.Errors

  describe "from_changeset/1" do
    test "converts simple validation errors" do
      changeset = Bazaar.Schemas.Shopping.CheckoutResp.new(%{})

      result = Errors.from_changeset(changeset)

      assert result["error"] == "validation_error"
      assert result["message"] == "Validation failed"
      assert is_list(result["details"])
    end

    test "includes field names in details" do
      changeset = Bazaar.Schemas.Shopping.CheckoutResp.new(%{})

      result = Errors.from_changeset(changeset)

      fields = Enum.map(result["details"], & &1["field"])
      assert "currency" in fields
      assert "line_items" in fields
    end

    test "includes error messages in details" do
      changeset = Bazaar.Schemas.Shopping.CheckoutResp.new(%{})

      result = Errors.from_changeset(changeset)

      currency_error = Enum.find(result["details"], &(&1["field"] == "currency"))
      assert currency_error["message"] == "can't be blank"
    end

    test "handles interpolated error messages" do
      # Create a changeset with a number validation error
      defmodule TestAmountSchema do
        use Ecto.Schema
        import Ecto.Changeset

        @primary_key false
        embedded_schema do
          field(:amount, :integer)
        end

        def changeset(struct \\ %__MODULE__{}, params) do
          struct
          |> cast(params, [:amount])
          |> validate_number(:amount, greater_than: 0)
        end
      end

      changeset = TestAmountSchema.changeset(%{"amount" => "-5"})
      result = Errors.from_changeset(changeset)

      amount_error = Enum.find(result["details"], &(&1["field"] == "amount"))
      assert amount_error["message"] =~ "greater than"
    end

    test "handles enum validation errors" do
      # Test with a schema that has enum validation
      defmodule TestStatusSchema do
        use Ecto.Schema
        import Ecto.Changeset

        @primary_key false
        embedded_schema do
          field(:status, Ecto.Enum, values: [:active, :inactive])
        end

        def changeset(struct \\ %__MODULE__{}, params) do
          struct
          |> cast(params, [:status])
          |> validate_required([:status])
        end
      end

      changeset = TestStatusSchema.changeset(%{"status" => "INVALID"})
      result = Errors.from_changeset(changeset)

      status_error = Enum.find(result["details"], &(&1["field"] == "status"))
      assert status_error["message"] == "is invalid"
    end

    test "flattens nested errors with dot notation" do
      # Create a changeset with nested embedded errors
      defmodule NestedItemSchema do
        use Ecto.Schema
        import Ecto.Changeset

        @primary_key false
        embedded_schema do
          field(:name, :string)
        end

        def changeset(struct \\ %__MODULE__{}, params) do
          struct
          |> cast(params, [:name])
          |> validate_required([:name])
        end
      end

      defmodule NestedSchema do
        use Ecto.Schema
        import Ecto.Changeset

        @primary_key false
        embedded_schema do
          embeds_many(:items, Bazaar.ErrorsTest.NestedItemSchema)
        end

        def changeset(struct \\ %__MODULE__{}, params) do
          struct
          |> cast(params, [])
          |> cast_embed(:items, with: &Bazaar.ErrorsTest.NestedItemSchema.changeset/2)
        end
      end

      changeset = NestedSchema.changeset(%{"items" => [%{}]})
      result = Errors.from_changeset(changeset)

      # Should have nested field paths like "items.0.name"
      fields = Enum.map(result["details"], & &1["field"])
      assert Enum.any?(fields, &String.contains?(&1, "items"))
    end

    test "handles multiple errors on same field" do
      # This test uses a custom schema to generate multiple errors
      defmodule MultiErrorSchema do
        use Ecto.Schema
        import Ecto.Changeset

        @primary_key false
        embedded_schema do
          field(:value, :integer)
        end

        def changeset(struct \\ %__MODULE__{}, params) do
          struct
          |> cast(params, [:value])
          |> validate_required([:value])
          |> validate_number(:value, greater_than: 0, less_than: 100)
        end
      end

      changeset = MultiErrorSchema.changeset(%{"value" => "-50"})
      result = Errors.from_changeset(changeset)

      value_errors =
        result["details"]
        |> Enum.filter(&(&1["field"] == "value"))

      assert value_errors != []
    end

    test "returns empty details for valid changeset" do
      # Use a simple custom schema to test valid changeset behavior
      defmodule ValidSchema do
        use Ecto.Schema
        import Ecto.Changeset

        @primary_key false
        embedded_schema do
          field(:name, :string)
        end

        def changeset(struct \\ %__MODULE__{}, params) do
          struct
          |> cast(params, [:name])
          |> validate_required([:name])
        end
      end

      changeset = ValidSchema.changeset(%{"name" => "test"})

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
      changeset = Bazaar.Schemas.Shopping.CheckoutResp.new(%{})
      result = Errors.from_changeset(changeset)

      assert is_binary(JSON.encode!(result))
    end

    test "not_found result is JSON encodable" do
      result = Errors.not_found("order", "123")

      assert is_binary(JSON.encode!(result))
    end

    test "from_reason result is JSON encodable" do
      result = Errors.from_reason(:forbidden)

      assert is_binary(JSON.encode!(result))
    end
  end
end
