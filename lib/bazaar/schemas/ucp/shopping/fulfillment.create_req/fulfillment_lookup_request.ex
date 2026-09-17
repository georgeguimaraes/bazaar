defmodule Bazaar.Schemas.Shopping.FulfillmentCreateReq.FulfillmentLookupRequest do
  @moduledoc """
  Schema

  Request body for catalog lookup.

  Generated from: fulfillment.create_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Context
  alias Bazaar.Schemas.Common.Types.Signals
  alias Bazaar.Schemas.Shopping.FulfillmentCreateReq.FulfillmentSearchFilters

  @field_descriptions %{
    attribution:
      "Platform-emitted referral and conversion-event context — campaign identifiers, click IDs, source/medium markers, etc. The same parameters platforms communicate via URL query parameters in browser-based flows.",
    context: nil,
    filters:
      "Catalog filters extended with a fulfillment destination filter and a method-type filter.",
    ids:
      "Identifiers to lookup. Implementations MUST support product ID and variant ID; MAY support secondary identifiers (SKU, handle, etc.).",
    signals: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:attribution, :map)
    field(:ids, {:array, :map})
    embeds_one(:context, Context)
    embeds_one(:filters, FulfillmentSearchFilters)
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
