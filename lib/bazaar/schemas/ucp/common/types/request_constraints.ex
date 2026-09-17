defmodule Bazaar.Schemas.Common.Types.RequestConstraints do
  @moduledoc """
  Request Constraints

  Binds the shared Constraint Expression grammar to data in the next UCP request to the same resource.

  Generated from: request_constraints.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.ConstraintExpression

  @field_descriptions %{
    anyOf:
      "Alternative Object Constraints. The constrained object must satisfy at least one. A branch must be non-empty: an empty branch is satisfied by every object and neutralizes the alternation.",
    path:
      "A complete RFC 9535 JSONPath query evaluated against the next logical UCP request to the same resource.",
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
    field(:path, :string)
    field(:properties, :map)
    field(:required, {:array, :map})
    embeds_many(:anyOf, ConstraintExpression)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:path, :properties, :required]) |> cast_embed(:anyOf, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
