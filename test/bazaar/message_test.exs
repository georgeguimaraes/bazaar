defmodule Bazaar.MessageTest do
  use ExUnit.Case, async: true

  alias Bazaar.Message

  describe "error/1" do
    test "creates error message changeset" do
      changeset =
        Message.error(%{
          "code" => "out_of_stock",
          "content" => "Item is unavailable",
          "severity" => "recoverable"
        })

      assert changeset.valid?
      data = Ecto.Changeset.apply_changes(changeset)
      assert data.code == "out_of_stock"
      assert data.content == "Item is unavailable"
      assert data.severity == :recoverable
    end

    test "requires code, content, and severity" do
      changeset = Message.error(%{})

      refute changeset.valid?
      errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
      assert errors[:code] == ["can't be blank"]
      assert errors[:content] == ["can't be blank"]
      assert errors[:severity] == ["can't be blank"]
    end

    test "accepts path" do
      changeset =
        Message.error(%{
          "code" => "invalid",
          "content" => "Invalid value",
          "severity" => "requires_buyer_input",
          "path" => "$.line_items[0].quantity"
        })

      assert changeset.valid?
      data = Ecto.Changeset.apply_changes(changeset)
      assert data.path == "$.line_items[0].quantity"
    end
  end

  describe "warning/1" do
    test "creates warning message changeset" do
      changeset =
        Message.warning(%{
          "code" => "price_changed",
          "content" => "Price has changed"
        })

      assert changeset.valid?
      data = Ecto.Changeset.apply_changes(changeset)
      assert data.code == "price_changed"
    end

    test "requires code and content" do
      changeset = Message.warning(%{})

      refute changeset.valid?
      errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
      assert errors[:code] == ["can't be blank"]
      assert errors[:content] == ["can't be blank"]
    end
  end

  describe "info/1" do
    test "creates info message changeset" do
      changeset =
        Message.info(%{
          "code" => "loyalty_points",
          "content" => "You earned 100 points"
        })

      assert changeset.valid?
      data = Ecto.Changeset.apply_changes(changeset)
      assert data.code == "loyalty_points"
    end
  end

  describe "parse/1" do
    test "routes to error/1 for error type" do
      assert {:ok, %Ecto.Changeset{valid?: true}} =
               Message.parse(%{
                 "type" => "error",
                 "code" => "invalid",
                 "content" => "Invalid",
                 "severity" => "recoverable"
               })
    end

    test "routes to warning/1 for warning type" do
      assert {:ok, %Ecto.Changeset{valid?: true}} =
               Message.parse(%{
                 "type" => "warning",
                 "code" => "notice",
                 "content" => "Notice"
               })
    end

    test "routes to info/1 for info type" do
      assert {:ok, %Ecto.Changeset{valid?: true}} =
               Message.parse(%{
                 "type" => "info",
                 "code" => "tip",
                 "content" => "Tip"
               })
    end

    test "returns error for missing type" do
      assert {:error, "type is required"} = Message.parse(%{"code" => "test"})
    end

    test "returns error for invalid type" do
      assert {:error, "type must be one of: error, warning, info"} =
               Message.parse(%{"type" => "invalid"})
    end
  end

  describe "type_values/0" do
    test "returns message types" do
      types = Message.type_values()

      assert :error in types
      assert :warning in types
      assert :info in types
    end
  end

  describe "severity_values/0" do
    test "returns severity values" do
      values = Message.severity_values()

      assert :recoverable in values
      assert :requires_buyer_input in values
      assert :requires_buyer_review in values
    end
  end

  describe "well_known_codes/0" do
    test "returns well-known error codes" do
      codes = Message.well_known_codes()

      assert "missing" in codes
      assert "invalid" in codes
      assert "out_of_stock" in codes
      assert "payment_declined" in codes
    end
  end
end
