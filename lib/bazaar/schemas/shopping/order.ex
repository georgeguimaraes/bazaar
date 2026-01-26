defmodule Bazaar.Schemas.Shopping.Order do
  @moduledoc """
  Order

  Order schema with immutable line items, buyer-facing fulfillment expectations, and append-only event logs.

  Generated from: order.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Types.Adjustment
  alias Bazaar.Schemas.Shopping.Types.OrderLineItem
  alias Bazaar.Schemas.Shopping.Types.TotalResp
  alias Bazaar.Schemas.Ucp.ResponseOrderSchema

  @field_descriptions %{
    adjustments:
      "Append-only event log of money movements (refunds, returns, credits, disputes, cancellations, etc.) that exist independently of fulfillment.",
    checkout_id: "Associated checkout ID for reconciliation.",
    fulfillment: "Fulfillment data: buyer expectations and what actually happened.",
    id: "Unique order identifier.",
    line_items: "Immutable line items — source of truth for what was ordered.",
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
    field(:permalink_url, :string)
    embeds_many(:adjustments, Adjustment)
    embeds_many(:line_items, OrderLineItem)
    embeds_many(:totals, TotalResp)
    embeds_one(:ucp, ResponseOrderSchema)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:checkout_id, :fulfillment, :id, :permalink_url])
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
