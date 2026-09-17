defmodule Bazaar.Schemas.Common.PaymentAp2MandateCompleteReq.DevUcpShoppingCheckout do
  @moduledoc """
  Checkout with AP2 Mandate Complete Request

  Checkout extended with AP2 mandate support.

  Generated from: payment_ap2_mandate.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.PaymentAp2MandateCompleteReq.Ap2WithCheckoutMandate
  alias Bazaar.Schemas.Common.Types.Payment
  alias Bazaar.Schemas.Common.Types.Signals

  @field_descriptions %{
    ap2: "AP2 extension data including checkout mandate.",
    attribution:
      "Platform-emitted referral and conversion-event context — campaign identifiers, click IDs, source/medium markers, etc. The same parameters platforms communicate via URL query parameters in browser-based flows.",
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
    embeds_one(:ap2, Ap2WithCheckoutMandate)
    embeds_one(:payment, Payment)
    embeds_one(:signals, Signals)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:attribution])
    |> cast_embed(:ap2, required: true)
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
