defmodule Bazaar.Schemas.Shopping.OrderCompleteReq do
  @moduledoc """
  Order Complete Request

  Order schema with line items, buyer-facing fulfillment expectations, and event logs.

  Generated from: order.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.TotalsCompleteReq
  alias Bazaar.Schemas.Shopping.Types.Adjustment
  alias Bazaar.Schemas.Shopping.Types.OrderLineItem
  alias Bazaar.Schemas.UcpCompleteReq.ResponseOrderSchema
  @doc "Returns the description for a field, if available."
  def field_description(:adjustments) do
    "Post-order events (refunds, returns, credits, disputes, cancellations, etc.) that exist independently of fulfillment."
  end

  def field_description(:checkout_id) do
    "Associated checkout ID for reconciliation."
  end

  def field_description(:fulfillment) do
    "Fulfillment data: buyer expectations and what actually happened."
  end

  def field_description(:id) do
    "Unique order identifier."
  end

  def field_description(:label) do
    "Human-readable label for identifying the order. MUST only be provided by the business."
  end

  def field_description(:line_items) do
    "Line items representing what was purchased — can change post-order via edits or exchanges."
  end

  def field_description(:messages) do
    "Business outcome messages (errors, warnings, informational). Present when the business needs to communicate status or issues to the platform."
  end

  def field_description(:permalink_url) do
    "Permalink to access the order on merchant site."
  end

  def field_description(:totals) do
    "Different totals for the order."
  end

  def field_description(:ucp) do
    nil
  end

  def field_description(field) when is_atom(field) do
    nil
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
    embeds_many(:totals, TotalsCompleteReq)
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
