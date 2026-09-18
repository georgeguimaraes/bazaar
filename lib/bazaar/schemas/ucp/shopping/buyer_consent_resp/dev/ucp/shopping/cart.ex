defmodule Bazaar.Schemas.Shopping.BuyerConsentResp.DevUcpShoppingCart do
  @moduledoc """
  Cart with Buyer Consent Response

  Cart extended with buyer consent.

  Generated from: buyer_consent_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Context
  alias Bazaar.Schemas.Common.Types.Link
  alias Bazaar.Schemas.Common.Types.Policy
  alias Bazaar.Schemas.Common.Types.Signals
  alias Bazaar.Schemas.Common.Types.TotalsResp
  alias Bazaar.Schemas.Shopping.BuyerConsentResp.Buyer
  alias Bazaar.Schemas.Shopping.Types.LineItemResp
  alias Bazaar.Schemas.UcpResp.ResponseCartSchema

  @field_descriptions %{
    actions: "Outstanding extension-defined Actions for this cart.",
    attribution:
      "Platform-emitted referral and conversion-event context — campaign identifiers, click IDs, source/medium markers, etc. The same parameters platforms communicate via URL query parameters in browser-based flows.",
    buyer: "Buyer with consent tracking.",
    context:
      "Buyer signals for localization (country, region, postal_code). Merchant uses for pricing, availability, currency. Falls back to geo-IP if omitted.",
    continue_url:
      "URL for cart handoff and session recovery. Enables sharing and human-in-the-loop flows.",
    currency: "ISO 4217 currency code. Determined by merchant based on context or geo-IP.",
    expires_at: "Cart expiry timestamp (RFC 3339). Optional.",
    id: "Unique cart identifier.",
    line_items: "Cart line items. Same structure as checkout. Full replacement on update.",
    links: "Optional merchant links (policies, FAQs).",
    messages: "Validation messages, warnings, or informational notices.",
    policies:
      "Policies (e.g., return/refund terms) that apply to the items in this cart. `applies_to` targets are relative to the response root; when absent or empty, refer to the URLs in `links[]`.",
    signals: nil,
    totals: "Estimated cost breakdown. May be partial if shipping/tax not yet calculable.",
    ucp: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:actions, :map)
    field(:attribution, :map)
    field(:continue_url, :string)
    field(:currency, :string)
    field(:expires_at, :utc_datetime)
    field(:id, :string)
    field(:messages, {:array, :map})
    embeds_one(:buyer, Buyer)
    embeds_one(:context, Context)
    embeds_many(:line_items, LineItemResp)
    embeds_many(:links, Link)
    embeds_many(:policies, Policy)
    embeds_one(:signals, Signals)
    embeds_many(:totals, TotalsResp)
    embeds_one(:ucp, ResponseCartSchema)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [
      :actions,
      :attribution,
      :continue_url,
      :currency,
      :expires_at,
      :id,
      :messages
    ])
    |> cast_embed(:buyer, required: false)
    |> cast_embed(:context, required: false)
    |> cast_embed(:line_items, required: true)
    |> cast_embed(:links, required: false)
    |> cast_embed(:policies, required: false)
    |> cast_embed(:signals, required: false)
    |> cast_embed(:totals, required: true)
    |> cast_embed(:ucp, required: true)
    |> validate_required([:id, :currency])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
