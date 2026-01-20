defmodule Bazaar.Discount do
  @moduledoc """
  Business logic helpers for UCP discount capability.

  Discounts enable businesses to apply promotional codes and automatic
  discounts to checkout sessions.

  ## Key Invariants

  - Sum of allocation amounts equals the discount amount
  - Rejected codes appear in `codes` but not in `applied`
  - Rejected codes communicated via messages with type "warning"
  """

  # Rejection codes for invalid/rejected discount codes
  @rejection_code_values [
    :discount_code_expired,
    :discount_code_invalid,
    :discount_code_already_applied,
    :discount_code_combination_disallowed,
    :discount_code_user_not_logged_in,
    :discount_code_user_ineligible
  ]

  # Allocation methods
  @allocation_method_values [:each, :across]

  # Discount-related total types
  @total_type_values [:items_discount, :discount]

  @doc "Returns the supported rejection codes for discount validation."
  def rejection_codes, do: @rejection_code_values

  @doc "Returns the supported allocation methods."
  def allocation_methods, do: @allocation_method_values

  @doc "Returns discount-related total types."
  def total_types, do: @total_type_values
end
