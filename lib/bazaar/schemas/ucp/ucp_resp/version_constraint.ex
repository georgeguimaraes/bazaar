defmodule Bazaar.Schemas.UcpResp.VersionConstraint do
  @moduledoc """
  Schema

  Version range requirement with minimum and optional maximum.

  Generated from: ucp_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @doc "Returns the description for a field, if available."
  def field_description(:max) do
    "Maximum compatible version (inclusive). When absent, no upper bound."
  end

  def field_description(:min) do
    "Minimum required version (inclusive)."
  end

  def field_description(field) when is_atom(field) do
    nil
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
