defmodule Bazaar.Schemas.Common.Types.Measure do
  @moduledoc """
  Measure

  A measure composed of an integer value and a unit descriptor. Its value is the integer count of `10^-scale` units of `unit`.

  Generated from: measure.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    display_text:
      "Required printable unit label provided by the Business. The Platform MUST use it when it does not recognize `unit`; for a recognized UN/CEFACT Rec 20 Common Code, the Platform MAY substitute its own localized label. It does not participate in unit identity or mismatch comparison.",
    scale:
      "One step equals `10^-scale` of `unit`. When `unit` is `C62`, `scale`, if present, MUST be 0. The maximum of 15 is derived from the interoperable integer range: at scale 16 a single whole unit (10^16 steps) is no longer representable, so larger scales cannot denominate one unit of their own basis. Businesses needing finer granularity use a smaller unit.",
    unit:
      "Stable machine identifier. The Business SHOULD use the exact UN/CEFACT Rec20 Common Code when one accurately identifies the unit. Otherwise, the Business MAY use a custom unit identifier and MUST use it consistently for the same unit. The Platform MUST treat an unrecognized identifier as opaque.",
    value: "Integer count of `10^-scale` units of `unit`."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:display_text, :string)
    field(:scale, :integer)
    field(:unit, :string)
    field(:value, :integer)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:display_text, :scale, :unit, :value])
    |> validate_required([:unit, :display_text, :value])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
