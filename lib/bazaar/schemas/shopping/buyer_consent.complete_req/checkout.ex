defmodule Bazaar.Schemas.Shopping.BuyerConsentCompleteReq.Checkout do
  @moduledoc """
  Checkout with Buyer Consent Complete Request

  Checkout extended with consent tracking via buyer object.

  Generated from: buyer_consent.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Payment
  @field_descriptions %{payment: nil}
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    embeds_one(:payment, Payment)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, []) |> cast_embed(:payment, required: true)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
