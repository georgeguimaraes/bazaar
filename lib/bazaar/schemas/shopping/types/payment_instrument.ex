defmodule Bazaar.Schemas.Shopping.Types.PaymentInstrument do
  @moduledoc """
  Payment Instrument
  
  Matches a specific instrument type based on validation logic.
  
  Generated from: payment_instrument.json
  """
  alias Bazaar.Schemas.Shopping.Types.CardPaymentInstrument
  @variants [Bazaar.Schemas.Shopping.Types.CardPaymentInstrument]
  @doc "Returns the variant modules for this union type."
  def variants do
    @variants
  end

  @doc "Casts params to one of the variant types."
  def cast(params) when is_map(params) do
    Enum.find_value([CardPaymentInstrument], {:error, :no_matching_variant}, fn mod ->
      case mod.new(params) do
        %Ecto.Changeset{valid?: true} = changeset -> {:ok, changeset}
        _ -> nil
      end
    end)
  end
end
