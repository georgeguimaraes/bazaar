defmodule Bazaar.Schemas.Shopping.Types.UnitPrice do
  @moduledoc """
  Unit Price

  Price per standard unit of measurement. MAY be omitted when unit pricing does not apply. `unit_price.currency` MUST equal `price.currency`; the comparator MUST NOT perform currency conversion. `measure.unit` and `reference.unit` MUST be identical; cross-unit conversion is not permitted. Their scales MAY differ; each value represents `value × 10^-scale`.

  Generated from: unit_price.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Measure

  @field_descriptions %{
    amount:
      "Unit price in ISO 4217 minor units. After satisfying the same-unit invariant, the Business MUST compute the comparator as `(price.amount / (measure.value × 10^-measure.scale)) × (reference.value × 10^-reference.scale)` and round it once to ISO 4217 minor units according to its pricing rules. The returned `unit_price.amount` is authoritative; the Platform MUST NOT recompute or substitute its own result.",
    currency: "ISO 4217 currency code.",
    measure:
      "Product quantity in packaging/content (for example, a 750 mL bottle), distinct from `quantity_unit`, which defines the sale basis. Its integer `value` MUST be at least 1.",
    reference:
      "Denominator for unit price display (for example, per 100 mL or per 1 kg). Its integer `value` MUST be at least 1."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:amount, :integer)
    field(:currency, :string)
    embeds_one(:measure, Measure)
    embeds_one(:reference, Measure)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:amount, :currency])
    |> cast_embed(:measure, required: true)
    |> cast_embed(:reference, required: true)
    |> validate_required([:amount, :currency])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
