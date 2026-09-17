defmodule Bazaar.Schemas.Common.Types.CardPaymentInstrument do
  @moduledoc """
  Card Payment Instrument

  A basic card payment instrument with visible card details. Can be inherited by a handler's instrument schema to define handler-specific display details or more complex credential structures.

  Generated from: card_payment_instrument.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.PaymentCredential
  alias Bazaar.Schemas.Common.Types.PostalAddress
  @type_values [:card]
  @field_descriptions %{
    billing_address: "The billing address associated with this payment method.",
    credential: nil,
    display: "Display information for this card payment instrument.",
    handler_id:
      "The unique identifier for the handler instance that produced this instrument. This corresponds to the 'id' field in the Payment Handler definition.",
    id:
      "A unique identifier for this instrument instance. Typically assigned by the platform for instruments it collects. For a business-owned saved instrument returned on an identity-linked response, this identifier is assigned by the business; the platform MUST treat it as an opaque, business-scoped reference, and the business resolves it server-side when the buyer selects it.",
    network:
      "Card network elected for this transaction, typically a co-badged selection. When present, the business MAY decline if the card cannot route over it and MUST NOT substitute another.",
    type: "Indicates this is a card payment instrument."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:display, :map)
    field(:handler_id, :string)
    field(:id, :string)
    field(:network, :string)
    field(:type, Ecto.Enum, values: @type_values)
    embeds_one(:billing_address, PostalAddress)
    embeds_one(:credential, PaymentCredential)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:display, :handler_id, :id, :network, :type])
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
