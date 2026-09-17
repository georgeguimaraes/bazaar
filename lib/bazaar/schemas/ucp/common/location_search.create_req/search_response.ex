defmodule Bazaar.Schemas.Common.LocationSearchCreateReq.SearchResponse do
  @moduledoc """
  Schema

  Generated from: location_search.create_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.LocationCreateReq
  alias Bazaar.Schemas.Common.Types.Pagination.Response
  alias Bazaar.Schemas.UcpCreateReq.ResponseLocationSchema

  @field_descriptions %{
    locations: "Locations matching the search criteria.",
    messages: "Errors, warnings, or informational messages about the search results.",
    pagination: nil,
    ucp: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:messages, {:array, :map})
    embeds_many(:locations, LocationCreateReq)
    embeds_one(:pagination, Response)
    embeds_one(:ucp, ResponseLocationSchema)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:messages])
    |> cast_embed(:locations, required: true)
    |> cast_embed(:pagination, required: false)
    |> cast_embed(:ucp, required: true)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
