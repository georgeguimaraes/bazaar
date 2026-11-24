defmodule Bazaar.Schemas.Shopping.CatalogSearchCompleteReq.SearchRequest do
  @moduledoc """
  Schema

  Generated from: catalog_search.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Context
  alias Bazaar.Schemas.Common.Types.Pagination.Request
  alias Bazaar.Schemas.Common.Types.Signals
  alias Bazaar.Schemas.Shopping.Types.SearchFilters
  @doc "Returns the description for a field, if available."
  def field_description(:attribution) do
    "Platform-emitted referral and conversion-event context — campaign identifiers, click IDs, source/medium markers, etc. The same parameters platforms communicate via URL query parameters in browser-based flows."
  end

  def field_description(:context) do
    nil
  end

  def field_description(:filters) do
    nil
  end

  def field_description(:pagination) do
    nil
  end

  def field_description(:query) do
    "Free-text search query."
  end

  def field_description(:signals) do
    nil
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:attribution, :map)
    field(:query, :string)
    embeds_one(:context, Context)
    embeds_one(:filters, SearchFilters)
    embeds_one(:pagination, Request)
    embeds_one(:signals, Signals)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:attribution, :query])
    |> cast_embed(:context, required: false)
    |> cast_embed(:filters, required: false)
    |> cast_embed(:pagination, required: false)
    |> cast_embed(:signals, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
