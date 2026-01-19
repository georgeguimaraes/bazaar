defmodule Bazaar.Schemas.DiscountTest do
  use ExUnit.Case, async: true

  alias Bazaar.Schemas.Discount

  describe "rejection_codes/0" do
    test "returns supported rejection codes" do
      codes = Discount.rejection_codes()

      assert :discount_code_expired in codes
      assert :discount_code_invalid in codes
      assert :discount_code_already_applied in codes
      assert :discount_code_combination_disallowed in codes
      assert :discount_code_user_not_logged_in in codes
      assert :discount_code_user_ineligible in codes
    end
  end

  describe "allocation_methods/0" do
    test "returns supported allocation methods" do
      methods = Discount.allocation_methods()

      assert :each in methods
      assert :across in methods
    end
  end

  describe "request_fields/0" do
    test "returns discount request field definitions" do
      fields = Discount.request_fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :codes end)
    end
  end

  describe "response_fields/0" do
    test "returns discount response field definitions" do
      fields = Discount.response_fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :codes end)
      assert Enum.any?(fields, fn f -> f.name == :applied end)
    end
  end

  describe "applied_discount_fields/0" do
    test "returns applied discount field definitions" do
      fields = Discount.applied_discount_fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :code end)
      assert Enum.any?(fields, fn f -> f.name == :title end)
      assert Enum.any?(fields, fn f -> f.name == :amount end)
      assert Enum.any?(fields, fn f -> f.name == :automatic end)
      assert Enum.any?(fields, fn f -> f.name == :method end)
      assert Enum.any?(fields, fn f -> f.name == :priority end)
      assert Enum.any?(fields, fn f -> f.name == :allocations end)
    end
  end

  describe "allocation_fields/0" do
    test "returns allocation field definitions" do
      fields = Discount.allocation_fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :path end)
      assert Enum.any?(fields, fn f -> f.name == :amount end)
    end
  end

  describe "total_types/0" do
    test "returns discount-related total types" do
      types = Discount.total_types()

      assert :items_discount in types
      assert :discount in types
    end
  end
end
