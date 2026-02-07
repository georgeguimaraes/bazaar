defmodule Bazaar.Schemas.Shopping.Ap2MandateCompleteReq.Checkout do
  @moduledoc """
  Checkout with AP2 Mandate Complete Request

  Checkout extended with AP2 mandate support.

  Generated from: ap2_mandate.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Ap2MandateCompleteReq.Ap2WithCheckoutMandate
  alias Bazaar.Schemas.Shopping.Payment
  @field_descriptions %{ap2: "AP2 extension data including checkout mandate.", payment: nil}
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    embeds_one(:ap2, Ap2WithCheckoutMandate)
    embeds_one(:payment, Payment)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [])
    |> cast_embed(:ap2, required: false)
    |> cast_embed(:payment, required: true)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
