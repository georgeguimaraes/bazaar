defmodule Bazaar.Schemas.Common.Types.NetworkTokenCredential do
  @moduledoc """
  Network Token Credential

  A card-network token credential verified with a transaction cryptogram. The `number` field carries the network token or wallet-provisioned token rather than the underlying FPAN.

  Generated from: network_token_credential.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @type_values [:network_token]
  @field_descriptions %{
    cryptogram:
      "Transaction cryptogram or dynamic CVC (dCVV), in the long or short form expected by the card network or processor.",
    eci_value:
      "Electronic Commerce Indicator / Security Level Indicator associated with the transaction.",
    expiry_month: "The month of the token's expiration date (1-12).",
    expiry_year: "The year of the token's expiration date.",
    name: "Cardholder name.",
    number: "Network token or wallet-provisioned token replacing the underlying FPAN.",
    token_requestor_id:
      "Payment network token requestor identifier, when required by the processor or network-token program.",
    type: "The credential type identifier for network token credentials."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:cryptogram, :string)
    field(:eci_value, :string)
    field(:expiry_month, :integer)
    field(:expiry_year, :integer)
    field(:name, :string)
    field(:number, :string)
    field(:token_requestor_id, :string)
    field(:type, Ecto.Enum, values: @type_values)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [
      :cryptogram,
      :eci_value,
      :expiry_month,
      :expiry_year,
      :name,
      :number,
      :token_requestor_id,
      :type
    ])
    |> validate_required([:type, :number, :cryptogram])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
