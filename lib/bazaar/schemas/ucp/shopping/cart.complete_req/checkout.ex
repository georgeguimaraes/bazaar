defmodule Bazaar.Schemas.Shopping.CartCompleteReq.Checkout do
  @moduledoc """
  Checkout with Cart Complete Request

  Checkout extended with cart capability. Adds cart_id to create_checkout for cart-to-checkout conversion.

  Generated from: cart.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Payment
  alias Bazaar.Schemas.Common.Types.Signals

  @field_descriptions %{
    attribution:
      "Platform-emitted referral and conversion-event context — campaign identifiers, click IDs, source/medium markers, etc. The same parameters platforms communicate via URL query parameters in browser-based flows.",
    cart_id:
      "Cart ID to convert to checkout. Business MUST use cart contents (line_items, context, buyer) and MUST ignore overlapping fields in checkout payload.",
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
    embeds_one(:payment, Payment)
    embeds_one(:signals, Signals)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:attribution, :cart_id])
    |> cast_embed(:payment, required: true)
    |> cast_embed(:signals, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
