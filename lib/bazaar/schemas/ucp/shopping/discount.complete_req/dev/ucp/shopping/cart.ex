defmodule Bazaar.Schemas.Shopping.DiscountCompleteReq.DevUcpShoppingCart do
  @moduledoc """
  Cart with Discount Complete Request

  Cart extended with discount capability.

  Generated from: discount.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Context
  alias Bazaar.Schemas.Common.Types.Signals
  alias Bazaar.Schemas.Shopping.DiscountCompleteReq.DiscountsObject
  alias Bazaar.Schemas.Shopping.Types.Buyer
  alias Bazaar.Schemas.Shopping.Types.LineItemCompleteReq
  @doc "Returns the description for a field, if available."
  def field_description(:attribution) do
    "Platform-emitted referral and conversion-event context — campaign identifiers, click IDs, source/medium markers, etc. The same parameters platforms communicate via URL query parameters in browser-based flows."
  end

  def field_description(:buyer) do
    "Optional buyer information for personalized estimates."
  end

  def field_description(:context) do
    "Buyer signals for localization (country, region, postal_code). Merchant uses for pricing, availability, currency. Falls back to geo-IP if omitted."
  end

  def field_description(:discounts) do
    "Discount codes input and applied discounts output."
  end

  def field_description(:line_items) do
    "Cart line items. Same structure as checkout. Full replacement on update."
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
    embeds_one(:discounts, DiscountsObject)
    embeds_many(:line_items, LineItemCompleteReq)
    embeds_one(:signals, Signals)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:attribution])
    |> cast_embed(:buyer, required: false)
    |> cast_embed(:context, required: false)
    |> cast_embed(:discounts, required: false)
    |> cast_embed(:line_items, required: true)
    |> cast_embed(:signals, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
