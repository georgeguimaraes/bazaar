defmodule Bazaar.Schemas.Common.Types.InstrumentGroup do
  @moduledoc """
  Instrument Group

  A constraint within an allowed combination that defines which instrument types can fill this group and how many are permitted.

  Generated from: instrument_group.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    max:
      "Maximum number of instruments allowed from this group. Defaults to 1. MUST be greater than or equal to `min`.",
    min: "Minimum number of instruments required from this group. Defaults to 0 (optional).",
    types: "Instrument types accepted by this group (OR logic). Any listed type qualifies."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:max, :integer)
    field(:min, :integer)
    field(:types, {:array, :map})
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:max, :min, :types]) |> validate_required([:types])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
