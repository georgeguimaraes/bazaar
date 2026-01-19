defmodule Bazaar.Schemas.MessageTest do
  use ExUnit.Case, async: true

  alias Bazaar.Schemas.Message

  describe "error/1" do
    test "creates valid error message with required fields" do
      params = %{
        "code" => "payment_declined",
        "content" => "Your card was declined",
        "severity" => "requires_buyer_input"
      }

      changeset = Message.error(params)

      assert changeset.valid?
      data = Ecto.Changeset.apply_changes(changeset)
      assert data.type == :error
      assert data.code == "payment_declined"
      assert data.severity == :requires_buyer_input
    end

    test "returns invalid changeset when code is missing" do
      params = %{
        "content" => "Error message",
        "severity" => "recoverable"
      }

      changeset = Message.error(params)

      refute changeset.valid?
      errors = Keyword.keys(changeset.errors)
      assert :code in errors
    end

    test "returns invalid changeset when severity is missing" do
      params = %{
        "code" => "error",
        "content" => "Error message"
      }

      changeset = Message.error(params)

      refute changeset.valid?
      errors = Keyword.keys(changeset.errors)
      assert :severity in errors
    end

    test "accepts all valid severity values" do
      severities = Message.severity_values()

      for severity <- severities do
        params = %{
          "code" => "test_error",
          "content" => "Test error message",
          "severity" => to_string(severity)
        }

        changeset = Message.error(params)
        assert changeset.valid?, "Expected severity '#{severity}' to be valid"
      end
    end

    test "accepts optional path field" do
      params = %{
        "code" => "invalid",
        "content" => "Field is invalid",
        "severity" => "recoverable",
        "path" => "$.line_items[0].quantity"
      }

      changeset = Message.error(params)

      assert changeset.valid?
      data = Ecto.Changeset.apply_changes(changeset)
      assert data.path == "$.line_items[0].quantity"
    end

    test "accepts content_type field" do
      params = %{
        "code" => "error",
        "content" => "**Error**: Something went wrong",
        "severity" => "recoverable",
        "content_type" => "markdown"
      }

      changeset = Message.error(params)

      assert changeset.valid?
      data = Ecto.Changeset.apply_changes(changeset)
      assert data.content_type == :markdown
    end
  end

  describe "warning/1" do
    test "creates valid warning message" do
      params = %{
        "code" => "price_changed",
        "content" => "The price has changed since you added this item"
      }

      changeset = Message.warning(params)

      assert changeset.valid?
      data = Ecto.Changeset.apply_changes(changeset)
      assert data.type == :warning
      assert data.code == "price_changed"
    end

    test "does not require severity" do
      params = %{
        "code" => "warning",
        "content" => "Warning message"
      }

      changeset = Message.warning(params)

      assert changeset.valid?
    end
  end

  describe "info/1" do
    test "creates valid info message" do
      params = %{
        "code" => "free_shipping",
        "content" => "You qualify for free shipping!"
      }

      changeset = Message.info(params)

      assert changeset.valid?
      data = Ecto.Changeset.apply_changes(changeset)
      assert data.type == :info
      assert data.code == "free_shipping"
    end
  end

  describe "parse/1" do
    test "routes to error/1 for error type" do
      params = %{
        "type" => "error",
        "code" => "test",
        "content" => "Test",
        "severity" => "recoverable"
      }

      result = Message.parse(params)

      assert %Ecto.Changeset{valid?: true} = result
      data = Ecto.Changeset.apply_changes(result)
      assert data.type == :error
    end

    test "routes to warning/1 for warning type" do
      params = %{
        "type" => "warning",
        "code" => "test",
        "content" => "Test"
      }

      result = Message.parse(params)

      assert %Ecto.Changeset{valid?: true} = result
      data = Ecto.Changeset.apply_changes(result)
      assert data.type == :warning
    end

    test "routes to info/1 for info type" do
      params = %{
        "type" => "info",
        "code" => "test",
        "content" => "Test"
      }

      result = Message.parse(params)

      assert %Ecto.Changeset{valid?: true} = result
      data = Ecto.Changeset.apply_changes(result)
      assert data.type == :info
    end

    test "returns error for missing type" do
      params = %{"code" => "test", "content" => "Test"}

      result = Message.parse(params)

      assert {:error, "type is required"} = result
    end

    test "returns error for invalid type" do
      params = %{"type" => "invalid", "code" => "test", "content" => "Test"}

      result = Message.parse(params)

      assert {:error, "type must be one of: error, warning, info"} = result
    end
  end

  describe "validate_messages/1" do
    test "validates list of valid messages" do
      messages = [
        %{"type" => "error", "code" => "e1", "content" => "Error", "severity" => "recoverable"},
        %{"type" => "warning", "code" => "w1", "content" => "Warning"},
        %{"type" => "info", "code" => "i1", "content" => "Info"}
      ]

      result = Message.validate_messages(messages)

      assert {:ok, validated} = result
      assert length(validated) == 3
      assert Enum.at(validated, 0).type == :error
      assert Enum.at(validated, 1).type == :warning
      assert Enum.at(validated, 2).type == :info
    end

    test "returns errors for invalid messages" do
      messages = [
        %{"type" => "error", "code" => "e1", "content" => "Error", "severity" => "recoverable"},
        %{"type" => "error", "code" => "e2"}
      ]

      result = Message.validate_messages(messages)

      assert {:error, errors} = result
      assert length(errors) == 1
      {idx, _error} = hd(errors)
      assert idx == 1
    end
  end

  describe "well_known_codes/0" do
    test "returns list of well-known error codes" do
      codes = Message.well_known_codes()

      assert is_list(codes)
      assert "missing" in codes
      assert "invalid" in codes
      assert "out_of_stock" in codes
      assert "payment_declined" in codes
      assert "requires_sign_in" in codes
      assert "requires_3ds" in codes
      assert "requires_identity_linking" in codes
    end
  end
end
