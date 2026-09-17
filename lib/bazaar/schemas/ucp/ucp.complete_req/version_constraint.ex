defmodule Bazaar.Schemas.UcpCompleteReq.VersionConstraint do
  @moduledoc """
  Schema

  Version range requirement with minimum and optional maximum.

  Generated from: ucp.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    max: "Maximum compatible version (inclusive). When absent, no upper bound.",
    min: "Minimum required version (inclusive)."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:max, :string)
    field(:min, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:max, :min]) |> validate_required([:min])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
