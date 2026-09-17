defmodule Bazaar.Schemas.Common.Types.PanCredential do
  @moduledoc """
  PAN Credential

  A card credential carrying a funding primary account number (FPAN). Credential selection follows the shape of the value on the wire rather than its provenance: a network token surfaced in PAN form and verified with a `cvc` - as with credentials where a dynamic verification code proxies the cryptogram - is carried here, while a token verified with a discrete `cryptogram` uses Network Token Credential. This credential type MUST NOT be used for checkout, only with payment handlers that tokenize or encrypt credentials. CRITICAL: Both parties handling a PAN credential (sender and receiver) MUST be PCI DSS compliant. Transmission MUST use HTTPS/TLS with strong cipher suites.

  Generated from: pan_credential.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @type_values [:pan]
  @field_descriptions %{
    cvc: "Card verification code.",
    expiry_month: "The month of the card's expiration date (1-12).",
    expiry_year: "The year of the card's expiration date.",
    name: "Cardholder name.",
    number: "Funding primary account number (FPAN).",
    type: "The credential type identifier for PAN credentials."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:cvc, :string)
    field(:expiry_month, :integer)
    field(:expiry_year, :integer)
    field(:name, :string)
    field(:number, :string)
    field(:type, Ecto.Enum, values: @type_values)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:cvc, :expiry_month, :expiry_year, :name, :number, :type])
    |> validate_required([:type, :number])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
