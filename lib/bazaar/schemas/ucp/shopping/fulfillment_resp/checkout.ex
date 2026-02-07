defmodule Bazaar.Schemas.Shopping.FulfillmentResp.Checkout do
  @moduledoc """
  Checkout with Fulfillment Response

  Checkout extended with hierarchical fulfillment.

  Generated from: fulfillment_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Payment
  alias Bazaar.Schemas.Shopping.Types.Buyer
  alias Bazaar.Schemas.Shopping.Types.FulfillmentResp
  alias Bazaar.Schemas.Shopping.Types.LineItemResp
  alias Bazaar.Schemas.Shopping.Types.Link
  alias Bazaar.Schemas.Shopping.Types.OrderConfirmation
  alias Bazaar.Schemas.Shopping.Types.TotalResp
  alias Bazaar.Schemas.Ucp.ResponseCheckoutSchema

  @status_values [
    :incomplete,
    :requires_escalation,
    :ready_for_complete,
    :complete_in_progress,
    :completed,
    :canceled
  ]
  @field_descriptions %{
    buyer: "Representation of the buyer.",
    continue_url:
      "URL for checkout handoff and session recovery. MUST be provided when status is requires_escalation. See specification for format and availability requirements.",
    currency:
      "ISO 4217 currency code reflecting the merchant's market determination. Derived from address, context, and geo IP—buyers provide signals, merchants determine currency.",
    expires_at: "RFC 3339 expiry timestamp. Default TTL is 6 hours from creation if not sent.",
    fulfillment: "Fulfillment details.",
    id: "Unique identifier of the checkout session.",
    line_items: "List of line items being checked out.",
    links:
      "Links to be displayed by the platform (Privacy Policy, TOS). Mandatory for legal compliance.",
    messages: "List of messages with error and info about the checkout session state.",
    order: "Details about an order created for this checkout session.",
    payment: nil,
    status:
      "Checkout state indicating the current phase and required action. See Checkout Status lifecycle documentation for state transition details.",
    totals: "Different cart totals.",
    ucp: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:continue_url, :string)
    field(:currency, :string)
    field(:expires_at, :utc_datetime)
    field(:id, :string)
    field(:messages, {:array, :map})
    field(:status, Ecto.Enum, values: @status_values)
    embeds_one(:buyer, Buyer)
    embeds_one(:fulfillment, FulfillmentResp)
    embeds_many(:line_items, LineItemResp)
    embeds_many(:links, Link)
    embeds_one(:order, OrderConfirmation)
    embeds_one(:payment, Payment)
    embeds_many(:totals, TotalResp)
    embeds_one(:ucp, ResponseCheckoutSchema)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:continue_url, :currency, :expires_at, :id, :messages, :status])
    |> cast_embed(:buyer, required: false)
    |> cast_embed(:fulfillment, required: false)
    |> cast_embed(:line_items, required: true)
    |> cast_embed(:links, required: true)
    |> cast_embed(:order, required: false)
    |> cast_embed(:payment, required: false)
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
