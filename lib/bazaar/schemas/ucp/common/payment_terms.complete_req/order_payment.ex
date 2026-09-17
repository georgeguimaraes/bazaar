defmodule Bazaar.Schemas.Common.PaymentTermsCompleteReq.OrderPayment do
  @moduledoc """
  Order Payment with Accepted Term Complete Request

  Order payment details carrying the term the Buyer accepted at checkout.

  Generated from: payment_terms.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.PaymentTerm

  @field_descriptions %{
    accepted_term:
      "The payment term the Buyer accepted at checkout. Businesses MUST carry it forward so the Order states the amounts owed and when, and MUST ensure its schedule amounts sum to the Order total. The available terms are checkout state and are not projected."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    embeds_one(:accepted_term, PaymentTerm)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, []) |> cast_embed(:accepted_term, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
