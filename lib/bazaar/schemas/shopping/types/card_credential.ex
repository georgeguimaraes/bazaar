defmodule Bazaar.Schemas.Shopping.Types.CardCredential do
  @moduledoc """
  Card Credential
  
  A card credential containing sensitive payment card details including raw Primary Account Numbers (PANs). This credential type MUST NOT be used for checkout, only with payment handlers that tokenize or encrypt credentials. CRITICAL: Both parties handling CardCredential (sender and receiver) MUST be PCI DSS compliant. Transmission MUST use HTTPS/TLS with strong cipher suites.
  
  Generated from: card_credential.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @card_number_type_values [:fpan, :network_token, :dpan]
  @type_values [:card]
  @field_descriptions %{
    card_number_type:
      "The type of card number. Network tokens are preferred with fallback to FPAN. See PCI Scope for more details.",
    cryptogram: "Cryptogram provided with network tokens.",
    cvc: "Card CVC number.",
    eci_value:
      "Electronic Commerce Indicator / Security Level Indicator provided with network tokens.",
    expiry_month: "The month of the card's expiration date (1-12).",
    expiry_year: "The year of the card's expiration date.",
    name: "Cardholder name.",
    number: "Card number.",
    type: "The credential type identifier for card credentials."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:cryptogram, :string)
    field(:cvc, :string)
    field(:eci_value, :string)
    field(:expiry_month, :integer)
    field(:expiry_year, :integer)
    field(:name, :string)
    field(:number, :string)
    field(:card_number_type, Ecto.Enum, values: @card_number_type_values)
    field(:type, Ecto.Enum, values: @type_values)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [
      :cryptogram,
      :cvc,
      :eci_value,
      :expiry_month,
      :expiry_year,
      :name,
      :number,
      :card_number_type,
      :type
    ])
    |> validate_required([:type, :card_number_type])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end