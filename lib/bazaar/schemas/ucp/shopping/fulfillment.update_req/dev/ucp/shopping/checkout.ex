defmodule Bazaar.Schemas.Shopping.FulfillmentUpdateReq.DevUcpShoppingCheckout do
  @moduledoc """
  Checkout with Fulfillment Update Request

  Checkout extended with hierarchical fulfillment.

  Generated from: fulfillment.update_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Context
  alias Bazaar.Schemas.Common.Types.Payment
  alias Bazaar.Schemas.Common.Types.Signals
  alias Bazaar.Schemas.Shopping.Types.Buyer
  alias Bazaar.Schemas.Shopping.Types.FulfillmentUpdateReq
  alias Bazaar.Schemas.Shopping.Types.LineItemUpdateReq
  @doc "Returns the description for a field, if available."
  def field_description(:attribution) do
    "Platform-emitted referral and conversion-event context — campaign identifiers, click IDs, source/medium markers, etc. The same parameters platforms communicate via URL query parameters in browser-based flows."
  end

  def field_description(:buyer) do
    "Representation of the buyer."
  end

  def field_description(:context) do
    nil
  end

  def field_description(:fulfillment) do
    "Fulfillment details."
  end

  def field_description(:line_items) do
    "List of line items being checked out."
  end

  def field_description(:payment) do
    nil
  end

  def field_description(:signals) do
    nil
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:attribution, :map)
    embeds_one(:buyer, Buyer)
    embeds_one(:context, Context)
    embeds_one(:fulfillment, FulfillmentUpdateReq)
    embeds_many(:line_items, LineItemUpdateReq)
    embeds_one(:payment, Payment)
    embeds_one(:signals, Signals)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:attribution])
    |> cast_embed(:buyer, required: false)
    |> cast_embed(:context, required: false)
    |> cast_embed(:fulfillment, required: false)
    |> cast_embed(:line_items, required: true)
    |> cast_embed(:payment, required: false)
    |> cast_embed(:signals, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
