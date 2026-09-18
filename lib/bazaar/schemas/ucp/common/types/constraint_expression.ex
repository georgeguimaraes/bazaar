defmodule Bazaar.Schemas.Common.Types.ConstraintExpression do
  @moduledoc """
  Constraint Expression

  A closed JSON Schema Draft 2020-12 constraint expression with Object and Value Constraint positions.

  Generated from: constraint_expression.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    anyOf:
      "Alternative Object Constraints. The constrained object must satisfy at least one. A branch must be non-empty: an empty branch is satisfied by every object and neutralizes the alternation.",
    properties:
      "Constraints keyed by property name. Must be non-empty: an empty object applies no constraint.",
    required:
      "Property names required by the constrained object. Must be non-empty: an empty array applies no constraint."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:anyOf, {:array, :map})
    field(:properties, :map)
    field(:required, {:array, :string})
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:anyOf, :properties, :required])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
