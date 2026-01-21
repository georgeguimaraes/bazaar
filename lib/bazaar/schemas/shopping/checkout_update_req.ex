defmodule Bazaar.Schemas.Shopping.CheckoutUpdateReq do
  @moduledoc """
  Checkout Update Request

  Composite schema for updating an existing checkout session.
  All fields are optional for partial updates.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Bazaar.Schemas.Shopping.Types.Buyer
  alias Bazaar.Schemas.Shopping.Types.FulfillmentReq
  alias Bazaar.Schemas.Shopping.Types.LineItemUpdateReq
  alias Bazaar.Schemas.Shopping.Types.PaymentHandlerUpdateReq

  @primary_key false
  embedded_schema do
    embeds_one(:buyer, Buyer)
    embeds_one(:fulfillment, FulfillmentReq)
    embeds_many(:line_items, LineItemUpdateReq)
    embeds_one(:payment, PaymentHandlerUpdateReq)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [])
    |> cast_embed(:buyer)
    |> cast_embed(:fulfillment)
    |> cast_embed(:line_items)
    |> cast_embed(:payment)
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}), do: changeset(params)
end
