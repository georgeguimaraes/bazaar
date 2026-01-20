defmodule Bazaar.DiscountTest do
  use ExUnit.Case, async: true

  alias Bazaar.Discount

  describe "rejection_codes/0" do
    test "returns rejection code values" do
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
    test "returns allocation method values" do
      methods = Discount.allocation_methods()

      assert :each in methods
      assert :across in methods
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
