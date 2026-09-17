defmodule Bazaar.Schemas.Common.LocationSearchUpdateReq.SearchRequest do
  @moduledoc """
  Schema

  Request body for location search. The `distance` and `serves` relations and every supplied `filters` predicate combine with AND; `query` does not relax them.

  Generated from: location_search.update_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Context
  alias Bazaar.Schemas.Common.Types.LocationDistance
  alias Bazaar.Schemas.Common.Types.LocationFilter
  alias Bazaar.Schemas.Common.Types.LocationServesUpdateReq
  alias Bazaar.Schemas.Common.Types.Pagination.Request
  alias Bazaar.Schemas.Common.Types.Signals

  @field_descriptions %{
    context: nil,
    distance:
      "Optional explicit-center radius predicate. When present, it combines with `serves` and every supplied `filters` predicate using AND.",
    filters: nil,
    pagination: nil,
    query:
      "Free-text search query for natural language location search (e.g., 'restaurants near me that deliver', 'hotels with pool').",
    serves:
      "Optional authoritative service-target predicate. When present, it combines with `distance` and every supplied `filters` predicate using AND.",
    signals: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:query, :string)
    embeds_one(:context, Context)
    embeds_one(:distance, LocationDistance)
    embeds_one(:filters, LocationFilter)
    embeds_one(:pagination, Request)
    embeds_one(:serves, LocationServesUpdateReq)
    embeds_one(:signals, Signals)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:query])
    |> cast_embed(:context, required: false)
    |> cast_embed(:distance, required: false)
    |> cast_embed(:filters, required: false)
    |> cast_embed(:pagination, required: false)
    |> cast_embed(:serves, required: false)
    |> cast_embed(:signals, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
