defmodule Bazaar.Schemas.Common.Types.LocationCompleteReq do
  @moduledoc """
  Location Complete Request

  The full, rich representation of a physical business location. Builds on the Location Summary schema with discovery-centric details such as geographic coordinates, operating hours, timezone, and amenities.

  Generated from: location.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @field_descriptions %{id: "Stable, opaque, Business-scoped Location identifier."}
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:id]) |> validate_required([:id])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
