defmodule Bazaar.Schemas.Shopping.BuyerConsentCompleteReq.DevUcpShoppingCart do
  @moduledoc """
  Cart with Buyer Consent Complete Request

  Cart extended with buyer consent.

  Generated from: buyer_consent.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Context
  alias Bazaar.Schemas.Common.Types.Signals
  alias Bazaar.Schemas.Shopping.BuyerConsentCompleteReq.Buyer
  alias Bazaar.Schemas.Shopping.Types.LineItemCompleteReq

  @field_descriptions %{
    attribution:
      "Platform-emitted referral and conversion-event context — campaign identifiers, click IDs, source/medium markers, etc. The same parameters platforms communicate via URL query parameters in browser-based flows.",
    buyer: "Buyer with consent tracking.",
    context:
      "Buyer signals for localization (country, region, postal_code). Merchant uses for pricing, availability, currency. Falls back to geo-IP if omitted.",
    line_items: "Cart line items. Same structure as checkout. Full replacement on update.",
    signals: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:attribution, :map)
    embeds_one(:buyer, Buyer)
    embeds_one(:context, Context)
    embeds_many(:line_items, LineItemCompleteReq)
    embeds_one(:signals, Signals)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:attribution])
    |> cast_embed(:buyer, required: false)
    |> cast_embed(:context, required: false)
    |> cast_embed(:line_items, required: true)
    |> cast_embed(:signals, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
