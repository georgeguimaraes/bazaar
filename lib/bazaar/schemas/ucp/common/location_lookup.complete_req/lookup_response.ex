defmodule Bazaar.Schemas.Common.LocationLookupCompleteReq.LookupResponse do
  @moduledoc """
  Schema

  Generated from: location_lookup.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.LocationLookupCompleteReq.LookupLocation
  alias Bazaar.Schemas.UcpCompleteReq.ResponseLocationSchema

  @field_descriptions %{
    locations:
      "Locations matching the requested identifiers and refinements. May contain fewer Locations if some identifiers do not resolve or their resolved Locations are filtered out, or more if one identifier resolves to multiple Locations. When multiple identifiers resolve to the same Location, one returned Location carries all corresponding `inputs` entries.",
    messages:
      "Errors, warnings, or informational messages about the requested Locations, including `batch_limit_applied` when the Business processes only its configured maximum number of identifiers.",
    ucp: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:messages, {:array, :map})
    embeds_many(:locations, LookupLocation)
    embeds_one(:ucp, ResponseLocationSchema)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:messages])
    |> cast_embed(:locations, required: true)
    |> cast_embed(:ucp, required: true)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
