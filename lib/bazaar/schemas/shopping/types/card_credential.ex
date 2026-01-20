defmodule Bazaar.Schemas.Shopping.Types.CardCredential do
  @moduledoc """
  Card Credential
  
  A card credential containing sensitive payment card details including raw Primary Account Numbers (PANs). This credential type MUST NOT be used for checkout, only with payment handlers that tokenize or encrypt credentials. CRITICAL: Both parties handling CardCredential (sender and receiver) MUST be PCI DSS compliant. Transmission MUST use HTTPS/TLS with strong cipher suites.
  
  Generated from: card_credential.json
  """
  import Ecto.Changeset
  @card_number_type_values [:fpan, :network_token, :dpan]
  @card_number_type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @card_number_type_values)
  @type_values [:card]
  @type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @type_values)
  @fields [
    %{
      name: :card_number_type,
      type: @card_number_type_type,
      description:
        "The type of card number. Network tokens are preferred with fallback to FPAN. See PCI Scope for more details."
    },
    %{name: :cryptogram, type: :string, description: "Cryptogram provided with network tokens."},
    %{name: :cvc, type: :string, description: "Card CVC number."},
    %{
      name: :eci_value,
      type: :string,
      description:
        "Electronic Commerce Indicator / Security Level Indicator provided with network tokens."
    },
    %{
      name: :expiry_month,
      type: :integer,
      description: "The month of the card's expiration date (1-12)."
    },
    %{name: :expiry_year, type: :integer, description: "The year of the card's expiration date."},
    %{name: :name, type: :string, description: "Cardholder name."},
    %{name: :number, type: :string, description: "Card number."},
    %{
      name: :type,
      type: @type_type,
      description: "The credential type identifier for card credentials."
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:type, :card_number_type])
  end
end