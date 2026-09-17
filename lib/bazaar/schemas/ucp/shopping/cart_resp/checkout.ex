defmodule Bazaar.Schemas.Shopping.CartResp.Checkout do
  @moduledoc """
  Checkout with Cart Response

  Checkout extended with cart capability. Adds cart_id to create_checkout for cart-to-checkout conversion.

  Generated from: cart_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Context
  alias Bazaar.Schemas.Common.Types.Link
  alias Bazaar.Schemas.Common.Types.Payment
  alias Bazaar.Schemas.Common.Types.Policy
  alias Bazaar.Schemas.Common.Types.Signals
  alias Bazaar.Schemas.Common.Types.TotalsResp
  alias Bazaar.Schemas.Shopping.Types.Buyer
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
  @field_descriptions %{
    actions: "Outstanding extension-defined Actions for this checkout.",
    attribution:
      "Platform-emitted referral and conversion-event context — campaign identifiers, click IDs, source/medium markers, etc. The same parameters platforms communicate via URL query parameters in browser-based flows.",
    buyer: "Representation of the buyer.",
    cart_id:
      "Cart ID to convert to checkout. Business MUST use cart contents (line_items, context, buyer) and MUST ignore overlapping fields in checkout payload.",
    context: nil,
    continue_url:
      "URL for checkout handoff and session recovery. MUST be provided when status is requires_escalation. See specification for format and availability requirements.",
    currency:
      "ISO 4217 currency code reflecting the merchant's market determination. Derived from address, context, and geo IP—buyers provide signals, merchants determine currency.",
    expires_at: "RFC 3339 expiry timestamp. Default TTL is 6 hours from creation if not sent.",
    id: "Unique identifier of the checkout session.",
    line_items: "List of line items being checked out.",
    links:
      "Links to be displayed by the platform (Privacy Policy, TOS). Mandatory for legal compliance.",
    messages: "List of messages with error and info about the checkout session state.",
    order: "Details about an order created for this checkout session.",
    payment: nil,
    policies:
      "Policies (e.g., return/refund terms) that apply to the items in this checkout. `applies_to` targets are relative to the response root; when absent or empty, refer to the URLs in `links[]`.",
    signals: nil,
    status:
      "Checkout state indicating the current phase and required processing. See Checkout Status lifecycle documentation for state transition details.",
    totals: "Different cart totals.",
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
    field(:cart_id, :string)
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
    embeds_one(:totals, TotalsResp)
    embeds_one(:ucp, ResponseCheckoutSchema)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [
      :actions,
      :attribution,
      :cart_id,
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
