defmodule Bazaar.Schemas.Shopping.CartCreateReq.Checkout do
  @moduledoc """
  Checkout with Cart Create Request

  Checkout extended with cart capability. Adds cart_id to create_checkout for cart-to-checkout conversion.

  Generated from: cart.create_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Context
  alias Bazaar.Schemas.Common.Types.Payment
  alias Bazaar.Schemas.Common.Types.Signals
  alias Bazaar.Schemas.Shopping.Types.Buyer
  alias Bazaar.Schemas.Shopping.Types.LineItemCreateReq

  @field_descriptions %{
    attribution:
      "Platform-emitted referral and conversion-event context — campaign identifiers, click IDs, source/medium markers, etc. The same parameters platforms communicate via URL query parameters in browser-based flows.",
    buyer: "Representation of the buyer.",
    cart_id:
      "Cart ID to convert to checkout. Business MUST use cart contents (line_items, context, buyer) and MUST ignore overlapping fields in checkout payload.",
    context: nil,
    line_items: "List of line items being checked out.",
    payment: nil,
    signals: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:attribution, :map)
    field(:cart_id, :string)
    embeds_one(:buyer, Buyer)
    embeds_one(:context, Context)
    embeds_many(:line_items, LineItemCreateReq)
    embeds_one(:payment, Payment)
    embeds_one(:signals, Signals)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:attribution, :cart_id])
    |> cast_embed(:buyer, required: false)
    |> cast_embed(:context, required: false)
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
