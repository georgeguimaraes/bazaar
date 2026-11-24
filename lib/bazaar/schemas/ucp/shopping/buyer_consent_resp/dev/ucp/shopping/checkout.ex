defmodule Bazaar.Schemas.Shopping.BuyerConsentResp.DevUcpShoppingCheckout do
  @moduledoc """
  Checkout with Buyer Consent Response

  Checkout extended with buyer consent.

  Generated from: buyer_consent_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Context
  alias Bazaar.Schemas.Common.Types.Link
  alias Bazaar.Schemas.Common.Types.Payment
  alias Bazaar.Schemas.Common.Types.Policy
  alias Bazaar.Schemas.Common.Types.Signals
  alias Bazaar.Schemas.Common.Types.TotalsResp
  alias Bazaar.Schemas.Shopping.BuyerConsentResp.Buyer
  alias Bazaar.Schemas.Shopping.Types.LineItemResp
  alias Bazaar.Schemas.Shopping.Types.OrderConfirmation
  alias Bazaar.Schemas.UcpResp.ResponseCheckoutSchema

  @status_values [
    :incomplete,
    :requires_escalation,
    :ready_for_complete,
    :complete_in_progress,
    :completed,
    :canceled
  ]
  @doc "Returns the description for a field, if available."
  def field_description(:actions) do
    "Outstanding extension-defined Actions for this checkout."
  end

  def field_description(:attribution) do
    "Platform-emitted referral and conversion-event context — campaign identifiers, click IDs, source/medium markers, etc. The same parameters platforms communicate via URL query parameters in browser-based flows."
  end

  def field_description(:buyer) do
    "Buyer with consent tracking."
  end

  def field_description(:context) do
    nil
  end

  def field_description(:continue_url) do
    "URL for checkout handoff and session recovery. MUST be provided when status is requires_escalation. See specification for format and availability requirements."
  end

  def field_description(:currency) do
    "ISO 4217 currency code reflecting the merchant's market determination. Derived from address, context, and geo IP—buyers provide signals, merchants determine currency."
  end

  def field_description(:expires_at) do
    "RFC 3339 expiry timestamp. Default TTL is 6 hours from creation if not sent."
  end

  def field_description(:id) do
    "Unique identifier of the checkout session."
  end

  def field_description(:line_items) do
    "List of line items being checked out."
  end

  def field_description(:links) do
    "Links to be displayed by the platform (Privacy Policy, TOS). Mandatory for legal compliance."
  end

  def field_description(:messages) do
    "List of messages with error and info about the checkout session state."
  end

  def field_description(:order) do
    "Details about an order created for this checkout session."
  end

  def field_description(:payment) do
    nil
  end

  def field_description(:policies) do
    "Policies (e.g., return/refund terms) that apply to the items in this checkout. `applies_to` targets are relative to the response root; when absent or empty, refer to the URLs in `links[]`."
  end

  def field_description(:signals) do
    nil
  end

  def field_description(:status) do
    "Checkout state indicating the current phase and required processing. See Checkout Status lifecycle documentation for state transition details."
  end

  def field_description(:totals) do
    "Different cart totals."
  end

  def field_description(:ucp) do
    nil
  end

  def field_description(field) when is_atom(field) do
    nil
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
    field(:status, Ecto.Enum, values: @status_values)
    embeds_one(:buyer, Buyer)
    embeds_one(:context, Context)
    embeds_many(:line_items, LineItemResp)
    embeds_many(:links, Link)
    embeds_one(:order, OrderConfirmation)
    embeds_one(:payment, Payment)
    embeds_many(:policies, Policy)
    embeds_one(:signals, Signals)
    embeds_many(:totals, TotalsResp)
    embeds_one(:ucp, ResponseCheckoutSchema)
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
      :messages,
      :status
    ])
    |> cast_embed(:buyer, required: false)
    |> cast_embed(:context, required: false)
    |> cast_embed(:line_items, required: true)
    |> cast_embed(:links, required: true)
    |> cast_embed(:order, required: false)
    |> cast_embed(:payment, required: false)
    |> cast_embed(:policies, required: false)
    |> cast_embed(:signals, required: false)
    |> cast_embed(:totals, required: true)
    |> cast_embed(:ucp, required: true)
    |> validate_required([:id, :status, :currency])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
