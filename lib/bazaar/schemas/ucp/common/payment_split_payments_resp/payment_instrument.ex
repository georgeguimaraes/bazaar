defmodule Bazaar.Schemas.Common.PaymentSplitPaymentsResp.PaymentInstrument do
  @moduledoc """
  Payment Instrument (Split Payments) Response

  Payment instrument extended with an optional per-instrument amount for split payments.

  Generated from: payment_split_payments_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.PaymentCredential
  alias Bazaar.Schemas.Common.Types.PostalAddress

  @field_descriptions %{
    amount:
      "Contribution amount for this instrument expressed in ISO 4217 minor units of the containing capability object's `currency`. On request: the platform's requested contribution (omit for open-amount). On response: the actual amount authorized or charged (omitted when not finally processed).",
    billing_address: "The billing address associated with this payment method.",
    credential: nil,
    display:
      "Display information for this payment instrument. Each payment instrument schema defines its specific display properties, as outlined by the payment handler.",
    handler_id:
      "The unique identifier for the handler instance that produced this instrument. This corresponds to the 'id' field in the Payment Handler definition.",
    id:
      "A unique identifier for this instrument instance. Typically assigned by the platform for instruments it collects. For a business-owned saved instrument returned on an identity-linked response, this identifier is assigned by the business; the platform MUST treat it as an opaque, business-scoped reference, and the business resolves it server-side when the buyer selects it.",
    type:
      "The broad category of the instrument (e.g., 'card', 'tokenized_card'). Specific schemas will constrain this to a constant value."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:amount, :integer)
    field(:display, :map)
    field(:handler_id, :string)
    field(:id, :string)
    field(:type, :string)
    embeds_one(:billing_address, PostalAddress)
    embeds_one(:credential, PaymentCredential)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:amount, :display, :handler_id, :id, :type])
    |> cast_embed(:billing_address, required: false)
    |> cast_embed(:credential, required: false)
    |> validate_required([:id, :handler_id, :type])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
