defmodule Bazaar.CheckoutTest do
  use ExUnit.Case, async: true

  alias Bazaar.Checkout

  describe "to_minor_units/1" do
    test "converts float dollars to cents" do
      assert Checkout.to_minor_units(19.99) == 1999
      assert Checkout.to_minor_units(0.01) == 1
      assert Checkout.to_minor_units(100.00) == 10000
    end

    test "converts integer dollars to cents" do
      assert Checkout.to_minor_units(20) == 2000
      assert Checkout.to_minor_units(1) == 100
      assert Checkout.to_minor_units(0) == 0
    end

    test "converts Decimal to cents" do
      assert Checkout.to_minor_units(Decimal.new("19.99")) == 1999
      assert Checkout.to_minor_units(Decimal.new("0.01")) == 1
      assert Checkout.to_minor_units(Decimal.new("100.50")) == 10050
    end

    test "handles rounding correctly" do
      # 19.995 should round to 2000 cents
      assert Checkout.to_minor_units(19.995) == 2000
      assert Checkout.to_minor_units(Decimal.new("19.995")) == 2000
    end
  end

  describe "to_major_units/1" do
    test "converts cents to dollars" do
      assert Checkout.to_major_units(1999) == 19.99
      assert Checkout.to_major_units(1) == 0.01
      assert Checkout.to_major_units(10000) == 100.0
    end

    test "handles zero" do
      assert Checkout.to_major_units(0) == 0.0
    end
  end

  describe "delegation to generated schema" do
    test "fields/0 returns field definitions" do
      fields = Checkout.fields()

      assert is_list(fields)
      field_names = Enum.map(fields, & &1.name)
      assert :currency in field_names
      assert :line_items in field_names
      assert :status in field_names
    end

    test "new/1 creates a changeset" do
      changeset = Checkout.new(%{})

      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?
    end
  end
end
