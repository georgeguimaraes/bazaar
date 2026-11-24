defmodule Bazaar.Schemas.Common.Types.PaymentInstrument.SelectedPaymentInstrument do
  @moduledoc """
  Selected Payment Instrument

  A payment instrument with selection state.

  Generated from: payment_instrument.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.PaymentCredential
  alias Bazaar.Schemas.Common.Types.PostalAddress
  @doc "Returns the description for a field, if available."
  def field_description(:billing_address) do
    "The billing address associated with this payment method."
  end

  def field_description(:credential) do
    nil
  end

  def field_description(:display) do
    "Display information for this payment instrument. Each payment instrument schema defines its specific display properties, as outlined by the payment handler."
  end

  def field_description(:handler_id) do
    "The unique identifier for the handler instance that produced this instrument. This corresponds to the 'id' field in the Payment Handler definition."
  end

  def field_description(:id) do
    "A unique identifier for this instrument instance. Typically assigned by the platform for instruments it collects. For a business-owned saved instrument returned on an identity-linked response, this identifier is assigned by the business; the platform MUST treat it as an opaque, business-scoped reference, and the business resolves it server-side when the buyer selects it."
  end

  def field_description(:selected) do
    "Whether this instrument is selected by the user."
  end

  def field_description(:type) do
    "The broad category of the instrument (e.g., 'card', 'tokenized_card'). Specific schemas will constrain this to a constant value."
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:display, :map)
    field(:handler_id, :string)
    field(:id, :string)
    field(:selected, :boolean)
    field(:type, :string)
    embeds_one(:billing_address, PostalAddress)
    embeds_one(:credential, PaymentCredential)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:display, :handler_id, :id, :selected, :type])
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
