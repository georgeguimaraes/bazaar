defmodule Bazaar.Schemas.Shopping.DiscountUpdateReq.Checkout do
  @moduledoc """
  Checkout with Discount Update Request

  Checkout extended with discount capability.

  Generated from: discount.update_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.DiscountUpdateReq.DiscountsObject
  alias Bazaar.Schemas.Shopping.Payment
  alias Bazaar.Schemas.Shopping.Types.Buyer
  alias Bazaar.Schemas.Shopping.Types.Context
  alias Bazaar.Schemas.Shopping.Types.LineItemUpdateReq

  @field_descriptions %{
    buyer: "Representation of the buyer.",
    context: nil,
    discounts: "Discount codes input and applied discounts output.",
    id: "Unique identifier of the checkout session.",
    line_items: "List of line items being checked out.",
    payment: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    embeds_one(:buyer, Buyer)
    embeds_one(:context, Context)
    embeds_one(:discounts, DiscountsObject)
    embeds_many(:line_items, LineItemUpdateReq)
    embeds_one(:payment, Payment)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:id])
    |> cast_embed(:buyer, required: false)
    |> cast_embed(:context, required: false)
    |> cast_embed(:discounts, required: false)
    |> cast_embed(:line_items, required: true)
    |> cast_embed(:payment, required: false)
    |> validate_required([:id])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
