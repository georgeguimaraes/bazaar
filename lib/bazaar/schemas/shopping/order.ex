defmodule Bazaar.Schemas.Shopping.Order do
  @moduledoc """
  Order
  
  Order schema with immutable line items, buyer-facing fulfillment expectations, and append-only event logs.
  
  Generated from: order.json
  """
  import Ecto.Changeset

  @fields [
    %{
      name: :adjustments,
      type:
        Schemecto.many(Bazaar.Schemas.Shopping.Types.Adjustment.fields(),
          with: &Function.identity/1
        ),
      description:
        "Append-only event log of money movements (refunds, returns, credits, disputes, cancellations, etc.) that exist independently of fulfillment."
    },
    %{
      name: :checkout_id,
      type: :string,
      description: "Associated checkout ID for reconciliation."
    },
    %{
      name: :fulfillment,
      type: :map,
      description: "Fulfillment data: buyer expectations and what actually happened."
    },
    %{name: :id, type: :string, description: "Unique order identifier."},
    %{
      name: :line_items,
      type:
        Schemecto.many(Bazaar.Schemas.Shopping.Types.OrderLineItem.fields(),
          with: &Function.identity/1
        ),
      description: "Immutable line items — source of truth for what was ordered."
    },
    %{
      name: :permalink_url,
      type: :string,
      description: "Permalink to access the order on merchant site."
    },
    %{
      name: :totals,
      type:
        Schemecto.many(Bazaar.Schemas.Shopping.Types.TotalResp.fields(),
          with: &Function.identity/1
        ),
      description: "Different totals for the order."
    },
    %{
      name: :ucp,
      type: Schemecto.one(Bazaar.Schemas.Ucp.ResponseOrder.fields(), with: &Function.identity/1)
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params)
    |> validate_required([
      :ucp,
      :id,
      :checkout_id,
      :permalink_url,
      :line_items,
      :fulfillment,
      :totals
    ])
  end
end