defmodule Bazaar.Schemas.Shopping.FulfillmentResp.FulfillmentGetProductRequest do
  @moduledoc """
  Schema

  Request body for single-product retrieval. Supports interactive variant narrowing via selected and preferences.

  Generated from: fulfillment_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Context
  alias Bazaar.Schemas.Common.Types.Signals
  alias Bazaar.Schemas.Shopping.FulfillmentResp.FulfillmentSearchFilters
  alias Bazaar.Schemas.Shopping.Types.SelectedOption

  @field_descriptions %{
    attribution:
      "Platform-emitted referral and conversion-event context — campaign identifiers, click IDs, source/medium markers, etc. The same parameters platforms communicate via URL query parameters in browser-based flows.",
    context: nil,
    filters:
      "Catalog filters extended with a fulfillment destination filter and a method-type filter.",
    id: "Product or variant identifier. Implementations MUST support product ID and variant ID.",
    preferences:
      "Option names in relaxation priority order. When no exact variant matches all selections, the server drops options from the end of this list first. E.g., ['Color', 'Size'] keeps Color and relaxes Size.",
    selected:
      "Partial or full option selections for interactive variant narrowing. When provided, response option values include availability signals (available, exists) relative to these selections.",
    signals: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:attribution, :map)
    field(:id, :string)
    field(:preferences, {:array, :string})
    embeds_one(:context, Context)
    embeds_one(:filters, FulfillmentSearchFilters)
    embeds_many(:selected, SelectedOption)
    embeds_one(:signals, Signals)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:attribution, :id, :preferences])
    |> cast_embed(:context, required: false)
    |> cast_embed(:filters, required: false)
    |> cast_embed(:selected, required: false)
    |> cast_embed(:signals, required: false)
    |> validate_required([:id])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
