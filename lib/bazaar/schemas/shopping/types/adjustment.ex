defmodule Bazaar.Schemas.Shopping.Types.Adjustment do
  @moduledoc """
  Adjustment
  
  Append-only event that exists independently of fulfillment. Typically represents money movements but can be any post-order change. Polymorphic type that can optionally reference line items.
  
  Generated from: adjustment.json
  """
  import Ecto.Changeset
  @status_values [:pending, :completed, :failed]
  @status_type Ecto.ParameterizedType.init(Ecto.Enum, values: @status_values)
  @fields [
    %{
      name: :amount,
      type: :integer,
      description:
        "Amount in minor units (cents) for refunds, credits, price adjustments (optional)."
    },
    %{
      name: :description,
      type: :string,
      description:
        "Human-readable reason or description (e.g., 'Defective item', 'Customer requested')."
    },
    %{name: :id, type: :string, description: "Adjustment event identifier."},
    %{
      name: :line_items,
      type: {:array, :map},
      description: "Which line items and quantities are affected (optional)."
    },
    %{
      name: :occurred_at,
      type: :utc_datetime,
      description: "RFC 3339 timestamp when this adjustment occurred."
    },
    %{name: :status, type: @status_type, description: "Adjustment status."},
    %{
      name: :type,
      type: :string,
      description:
        "Type of adjustment (open string). Typically money-related like: refund, return, credit, price_adjustment, dispute, cancellation. Can be any value that makes sense for the merchant's business."
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:id, :type, :occurred_at, :status])
  end
end