defmodule Bazaar.Schemas.Shopping.Types.CardPaymentInstrument do
  @moduledoc """
  Card Payment Instrument
  
  A basic card payment instrument with visible card details. Can be inherited by a handler's instrument schema to define handler-specific display details or more complex credential structures.
  
  Generated from: card_payment_instrument.json
  """
  import Ecto.Changeset
  @type_values [:card]
  @type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @type_values)
  @fields [
    %{
      name: :billing_address,
      type:
        Schemecto.one(Bazaar.Schemas.Shopping.Types.PostalAddress.fields(),
          with: &Function.identity/1
        ),
      description: "The billing address associated with this payment method."
    },
    %{
      name: :brand,
      type: :string,
      description: "The card brand/network (e.g., visa, mastercard, amex)."
    },
    %{name: :credential, type: :map},
    %{
      name: :expiry_month,
      type: :integer,
      description: "The month of the card's expiration date (1-12)."
    },
    %{name: :expiry_year, type: :integer, description: "The year of the card's expiration date."},
    %{
      name: :handler_id,
      type: :string,
      description:
        "The unique identifier for the handler instance that produced this instrument. This corresponds to the 'id' field in the Payment Handler definition."
    },
    %{
      name: :id,
      type: :string,
      description:
        "A unique identifier for this instrument instance, assigned by the Agent. Used to reference this specific instrument in the 'payment.selected_instrument_id' field."
    },
    %{name: :last_digits, type: :string, description: "Last 4 digits of the card number."},
    %{
      name: :rich_card_art,
      type: :string,
      description:
        "An optional URI to a rich image representing the card (e.g., card art provided by the issuer)."
    },
    %{
      name: :rich_text_description,
      type: :string,
      description:
        "An optional rich text description of the card to display to the user (e.g., 'Visa ending in 1234, expires 12/2025')."
    },
    %{name: :type, type: @type_type, description: "Indicates this is a card payment instrument."}
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params)
    |> validate_required([:id, :handler_id, :type, :brand, :last_digits])
  end
end