defmodule Bazaar.Schemas.Common.PaymentTermsCompleteReq.DevUcpShoppingCheckout do
  @moduledoc """
  Checkout with Payment Terms Complete Request

  Checkout extended with selectable payment terms.

  Generated from: payment_terms.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.PaymentTermsCompleteReq.Payment
  alias Bazaar.Schemas.Common.Types.Signals

  @field_descriptions %{
    attribution:
      "Platform-emitted referral and conversion-event context — campaign identifiers, click IDs, source/medium markers, etc. The same parameters platforms communicate via URL query parameters in browser-based flows.",
    payment: "Payment details with available and selected payment terms.",
    signals: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:attribution, :map)
    embeds_one(:payment, Payment)
    embeds_one(:signals, Signals)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:attribution])
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
