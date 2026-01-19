defmodule Bazaar.Schemas.Discount do
  @moduledoc """
  Schemas for UCP discount capability.

  Discounts enable businesses to apply promotional codes and automatic
  discounts to checkout sessions.

  ## During Checkout

  The agent sends discount codes, and the merchant responds with
  applied discounts and any rejection messages:

      # Agent request
      %{
        "discounts" => %{
          "codes" => ["SAVE10", "FREESHIP"]
        }
      }

      # Merchant response includes applied discounts
      %{
        "discounts" => %{
          "codes" => ["SAVE10", "FREESHIP"],
          "applied" => [
            %{
              "code" => "SAVE10",
              "title" => "10% Off",
              "amount" => 1000,
              "method" => "across",
              "allocations" => [
                %{"path" => "$.line_items[0]", "amount" => 500},
                %{"path" => "$.line_items[1]", "amount" => 500}
              ]
            }
          ]
        },
        "messages" => [
          %{
            "type" => "warning",
            "code" => "discount_code_expired",
            "content" => "Code FREESHIP has expired"
          }
        ]
      }

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
  @allocation_method_type Ecto.ParameterizedType.init(Ecto.Enum,
                            values: @allocation_method_values
                          )

  # Discount-related total types
  @total_type_values [:items_discount, :discount]

  # ============================================================================
  # Request Schemas (from agent)
  # ============================================================================

  @discount_request_fields [
    %{
      name: :codes,
      type: {:array, :string},
      description: "Discount codes to apply (case-insensitive, replacement semantics)"
    }
  ]

  # ============================================================================
  # Response Schemas (from merchant)
  # ============================================================================

  @allocation_fields [
    %{
      name: :path,
      type: :string,
      required: true,
      description: "JSONPath target (e.g., $.line_items[0])"
    },
    %{
      name: :amount,
      type: :integer,
      required: true,
      description: "Allocated amount in minor currency units"
    }
  ]

  @applied_discount_fields [
    %{name: :code, type: :string, description: "Discount code (omitted for automatic discounts)"},
    %{name: :title, type: :string, required: true, description: "Human-readable name"},
    %{
      name: :amount,
      type: :integer,
      required: true,
      description: "Total discount amount in minor currency units"
    },
    %{name: :automatic, type: :boolean, description: "True if merchant-applied automatically"},
    %{
      name: :method,
      type: @allocation_method_type,
      description: "Allocation method: each (per item) or across (distributed)"
    },
    %{name: :priority, type: :integer, description: "Stacking order (1 = first)"},
    %{name: :allocations, type: {:array, :map}, description: "Per-target breakdown"}
  ]

  @discount_response_fields [
    %{
      name: :codes,
      type: {:array, :string},
      description: "Submitted discount codes"
    },
    %{
      name: :applied,
      type: {:array, :map},
      description: "Successfully applied discounts"
    }
  ]

  # ============================================================================
  # Public API
  # ============================================================================

  @doc "Returns the supported rejection codes for discount validation."
  def rejection_codes, do: @rejection_code_values

  @doc "Returns the supported allocation methods."
  def allocation_methods, do: @allocation_method_values

  @doc "Returns discount request field definitions."
  def request_fields, do: @discount_request_fields

  @doc "Returns discount response field definitions."
  def response_fields, do: @discount_response_fields

  @doc "Returns applied discount field definitions."
  def applied_discount_fields, do: @applied_discount_fields

  @doc "Returns allocation field definitions."
  def allocation_fields, do: @allocation_fields

  @doc "Returns discount-related total types."
  def total_types, do: @total_type_values
end
