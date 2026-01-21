defmodule Bazaar.Schemas.Shopping.Types.PaymentCredential do
  @moduledoc """
  Payment Credential
  
  Container for sensitive payment data. Use the specific schema matching the 'type' field.
  
  Generated from: payment_credential.json
  """
  alias Bazaar.Schemas.Shopping.Types.CardCredential
  alias Bazaar.Schemas.Shopping.Types.TokenCredentialResp

  @variants [
    Bazaar.Schemas.Shopping.Types.TokenCredentialResp,
    Bazaar.Schemas.Shopping.Types.CardCredential
  ]
  @doc "Returns the variant modules for this union type."
  def variants do
    @variants
  end

  @doc "Casts params to one of the variant types."
  def cast(params) when is_map(params) do
    Enum.find_value(
      [TokenCredentialResp, CardCredential],
      {:error, :no_matching_variant},
      fn mod ->
        case mod.new(params) do
          %Ecto.Changeset{valid?: true} = changeset -> {:ok, changeset}
          _ -> nil
        end
      end
    )
  end
end
