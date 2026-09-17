defmodule Bazaar.Schemas.Shopping.OrderUpdateReq do
  @moduledoc """
  Order Update Request

  Order schema with line items, buyer-facing fulfillment expectations, and event logs.

  Generated from: order.update_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.TotalsUpdateReq
  alias Bazaar.Schemas.Shopping.Types.Adjustment
  alias Bazaar.Schemas.Shopping.Types.OrderLineItem
  alias Bazaar.Schemas.UcpUpdateReq.ResponseOrderSchema

  @field_descriptions %{
    adjustments:
      "Post-order events (refunds, returns, credits, disputes, cancellations, etc.) that exist independently of fulfillment.",
    checkout_id: "Associated checkout ID for reconciliation.",
    fulfillment: "Fulfillment data: buyer expectations and what actually happened.",
    id: "Unique order identifier.",
    label:
      "Human-readable label for identifying the order. MUST only be provided by the business.",
    line_items:
      "Line items representing what was purchased — can change post-order via edits or exchanges.",
    messages:
      "Business outcome messages (errors, warnings, informational). Present when the business needs to communicate status or issues to the platform.",
    permalink_url: "Permalink to access the order on merchant site.",
    totals: "Different totals for the order.",
    ucp: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:checkout_id, :string)
    field(:fulfillment, :map)
    field(:id, :string)
    field(:label, :string)
    field(:messages, {:array, :map})
    field(:permalink_url, :string)
    embeds_many(:adjustments, Adjustment)
    embeds_many(:line_items, OrderLineItem)
    embeds_one(:totals, TotalsUpdateReq)
    embeds_one(:ucp, ResponseOrderSchema)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:checkout_id, :fulfillment, :id, :label, :messages, :permalink_url])
    |> cast_embed(:adjustments, required: false)
    |> cast_embed(:line_items, required: true)
    |> cast_embed(:totals, required: true)
    |> cast_embed(:ucp, required: true)
    |> validate_required([:id, :checkout_id, :permalink_url, :fulfillment])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
