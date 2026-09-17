defmodule Bazaar.Schemas.Shopping.OrderResp do
  @moduledoc """
  Order Response

  Order schema with line items, buyer-facing fulfillment expectations, and event logs.

  Generated from: order_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Policy
  alias Bazaar.Schemas.Common.Types.TotalsResp
  alias Bazaar.Schemas.Shopping.Types.Adjustment
  alias Bazaar.Schemas.Shopping.Types.OrderLineItem
  alias Bazaar.Schemas.UcpResp.ResponseOrderSchema

  @field_descriptions %{
    adjustments:
      "Post-order events (refunds, returns, credits, disputes, cancellations, etc.) that exist independently of fulfillment.",
    attribution:
      "Snapshot of the attribution associated with the originating checkout. Read-only on the order.",
    checkout_id: "Associated checkout ID for reconciliation.",
    currency:
      "ISO 4217 currency code. MUST match the currency from the originating checkout session.",
    fulfillment: "Fulfillment data: buyer expectations and what actually happened.",
    id: "Unique order identifier.",
    label:
      "Human-readable label for identifying the order. MUST only be provided by the business.",
    line_items:
      "Line items representing what was purchased — can change post-order via edits or exchanges.",
    messages:
      "Business outcome messages (errors, warnings, informational). Present when the business needs to communicate status or issues to the platform.",
    permalink_url: "Permalink to access the order on merchant site.",
    policies:
      "Snapshot of the policies that applied to the items at checkout, captured on the order as a durable record. `applies_to` targets are relative to the response root.",
    totals: "Different totals for the order.",
    ucp: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:attribution, :map)
    field(:checkout_id, :string)
    field(:currency, :string)
    field(:fulfillment, :map)
    field(:id, :string)
    field(:label, :string)
    field(:messages, {:array, :map})
    field(:permalink_url, :string)
    embeds_many(:adjustments, Adjustment)
    embeds_many(:line_items, OrderLineItem)
    embeds_many(:policies, Policy)
    embeds_one(:totals, TotalsResp)
    embeds_one(:ucp, ResponseOrderSchema)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [
      :attribution,
      :checkout_id,
      :currency,
      :fulfillment,
      :id,
      :label,
      :messages,
      :permalink_url
    ])
    |> cast_embed(:adjustments, required: false)
    |> cast_embed(:line_items, required: true)
    |> cast_embed(:policies, required: false)
    |> cast_embed(:totals, required: true)
    |> cast_embed(:ucp, required: true)
    |> validate_required([:id, :checkout_id, :permalink_url, :fulfillment, :currency])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
