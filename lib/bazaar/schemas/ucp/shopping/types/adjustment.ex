defmodule Bazaar.Schemas.Shopping.Types.Adjustment do
  @moduledoc """
  Adjustment

  Post-order event that exists independently of fulfillment. Typically represents money movements but can be any post-order change. Polymorphic type that can optionally reference line items.

  Generated from: adjustment.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.TotalResp
  @status_values [:pending, :completed, :failed]
  @field_descriptions %{
    description:
      "Human-readable reason or description (e.g., 'Defective item', 'Customer requested').",
    id: "Adjustment event identifier.",
    line_items: "Which line items and quantities are affected (optional).",
    occurred_at: "RFC 3339 timestamp when this adjustment occurred.",
    status: "Adjustment status.",
    totals:
      "Adjustment totals breakdown. Signed values - negative for money returned to buyer (refunds, credits), positive for additional charges (exchanges).",
    type:
      "Type of adjustment (open string). Typically money-related like: refund, return, credit, price_adjustment, dispute, cancellation. Can be any value that makes sense for the merchant's business."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:description, :string)
    field(:id, :string)
    field(:line_items, {:array, :map})
    field(:occurred_at, :utc_datetime)
    field(:type, :string)
    field(:status, Ecto.Enum, values: @status_values)
    embeds_many(:totals, TotalResp)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:description, :id, :line_items, :occurred_at, :type, :status])
    |> cast_embed(:totals, required: false)
    |> validate_required([:id, :type, :occurred_at, :status])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
