defmodule Bazaar.Schemas.Common.Types.LocationFilter do
  @moduledoc """
  Location Filter

  Filter criteria to narrow Location Search and Lookup results. All supplied filters combine with AND.

  Generated from: location_filter.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    amenities:
      "Filter by amenity identifier. A Location matches only when its `amenities` map contains every supplied identifier as an exact key; descriptions and namespace prefixes do not participate in matching.",
    hours: "Filter by operating hours, evaluated at the one supplied instant.",
    items:
      "Current item-availability filter. A candidate Location matches only when the Business can currently provide every referenced item at that Location; all references combine with AND."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:amenities, {:array, :map})
    field(:hours, :map)
    field(:items, {:array, :map})
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:amenities, :hours, :items])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
