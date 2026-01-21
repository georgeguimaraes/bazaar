defmodule Bazaar.Schemas.Shopping.Types.CardPaymentInstrument do
  @moduledoc """
  Card Payment Instrument
  
  A basic card payment instrument with visible card details. Can be inherited by a handler's instrument schema to define handler-specific display details or more complex credential structures.
  
  Generated from: card_payment_instrument.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Types.PostalAddress
  @type_values [:card]
  @field_descriptions %{
    billing_address: "The billing address associated with this payment method.",
    brand: "The card brand/network (e.g., visa, mastercard, amex).",
    credential: nil,
    expiry_month: "The month of the card's expiration date (1-12).",
    expiry_year: "The year of the card's expiration date.",
    handler_id:
      "The unique identifier for the handler instance that produced this instrument. This corresponds to the 'id' field in the Payment Handler definition.",
    id:
      "A unique identifier for this instrument instance, assigned by the Agent. Used to reference this specific instrument in the 'payment.selected_instrument_id' field.",
    last_digits: "Last 4 digits of the card number.",
    rich_card_art:
      "An optional URI to a rich image representing the card (e.g., card art provided by the issuer).",
    rich_text_description:
      "An optional rich text description of the card to display to the user (e.g., 'Visa ending in 1234, expires 12/2025').",
    type: "Indicates this is a card payment instrument."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:brand, :string)
    field(:credential, :map)
    field(:expiry_month, :integer)
    field(:expiry_year, :integer)
    field(:handler_id, :string)
    field(:id, :string)
    field(:last_digits, :string)
    field(:rich_card_art, :string)
    field(:rich_text_description, :string)
    field(:type, Ecto.Enum, values: @type_values)
    embeds_one(:billing_address, PostalAddress)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [
      :brand,
      :credential,
      :expiry_month,
      :expiry_year,
      :handler_id,
      :id,
      :last_digits,
      :rich_card_art,
      :rich_text_description,
      :type
    ])
    |> cast_embed(:billing_address, required: false)
    |> validate_required([:id, :handler_id, :type, :brand, :last_digits])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
