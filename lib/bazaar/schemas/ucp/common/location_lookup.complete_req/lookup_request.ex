defmodule Bazaar.Schemas.Common.LocationLookupCompleteReq.LookupRequest do
  @moduledoc """
  Schema

  Request body for batch location lookup. The Business resolves and deduplicates `ids` before applying `distance`, `serves`, and every supplied `filters` predicate; all structured predicates combine with AND.

  Generated from: location_lookup.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Context
  alias Bazaar.Schemas.Common.Types.LocationDistance
  alias Bazaar.Schemas.Common.Types.LocationFilter
  alias Bazaar.Schemas.Common.Types.LocationServesCompleteReq
  alias Bazaar.Schemas.Common.Types.Signals

  @field_descriptions %{
    context: nil,
    distance:
      "Optional explicit-center radius predicate applied after ID resolution. It combines with `serves` and every supplied `filters` predicate using AND.",
    filters: nil,
    ids:
      "Identifiers of the Locations to look up. The Business MUST support canonical `Location.id` values and MAY support secondary or alias identifiers.",
    serves:
      "Optional authoritative service-target predicate applied after ID resolution. It combines with `distance` and every supplied `filters` predicate using AND.",
    signals: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:ids, {:array, :map})
    embeds_one(:context, Context)
    embeds_one(:distance, LocationDistance)
    embeds_one(:filters, LocationFilter)
    embeds_one(:serves, LocationServesCompleteReq)
    embeds_one(:signals, Signals)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:ids])
    |> cast_embed(:context, required: false)
    |> cast_embed(:distance, required: false)
    |> cast_embed(:filters, required: false)
    |> cast_embed(:serves, required: false)
    |> cast_embed(:signals, required: false)
    |> validate_required([:ids])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
