defmodule Bazaar.Schemas.Common.Types.Geo do
  @moduledoc """
  Geo

  WGS 84 geographic coordinates in decimal degrees.

  Generated from: geo.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    latitude: "WGS 84 latitude in decimal degrees.",
    longitude: "WGS 84 longitude in decimal degrees."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:latitude, :float)
    field(:longitude, :float)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:latitude, :longitude]) |> validate_required([:latitude, :longitude])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
