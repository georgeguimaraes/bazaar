defmodule Bazaar.Schemas.Shopping.CatalogLookupCompleteReq.LookupRequest do
  @moduledoc """
  Schema

  Request body for catalog lookup.

  Generated from: catalog_lookup.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Context
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
    "Filter criteria to narrow returned products and variants. All specified filters combine with AND logic."
  end

  def field_description(:ids) do
    "Identifiers to lookup. Implementations MUST support product ID and variant ID; MAY support secondary identifiers (SKU, handle, etc.)."
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
    field(:ids, {:array, :string})
    embeds_one(:context, Context)
    embeds_one(:filters, SearchFilters)
    embeds_one(:signals, Signals)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:attribution, :ids])
    |> cast_embed(:context, required: false)
    |> cast_embed(:filters, required: false)
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
