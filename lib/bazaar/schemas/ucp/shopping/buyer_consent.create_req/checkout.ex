defmodule Bazaar.Schemas.Shopping.BuyerConsentCreateReq.Checkout do
  @moduledoc """
  Checkout with Buyer Consent Create Request

  Checkout extended with consent tracking via buyer object.

  Generated from: buyer_consent.create_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.BuyerConsentCreateReq.Buyer
  alias Bazaar.Schemas.Shopping.Payment
  alias Bazaar.Schemas.Shopping.Types.Context
  alias Bazaar.Schemas.Shopping.Types.LineItemCreateReq

  @field_descriptions %{
    buyer: "Buyer with consent tracking.",
    context: nil,
    line_items: "List of line items being checked out.",
    payment: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    embeds_one(:buyer, Buyer)
    embeds_one(:context, Context)
    embeds_many(:line_items, LineItemCreateReq)
    embeds_one(:payment, Payment)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [])
    |> cast_embed(:buyer, required: false)
    |> cast_embed(:context, required: false)
    |> cast_embed(:line_items, required: true)
    |> cast_embed(:payment, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
