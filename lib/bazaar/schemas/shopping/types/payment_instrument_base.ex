defmodule Bazaar.Schemas.Shopping.Types.PaymentInstrumentBase do
  @moduledoc """
  Payment Instrument Base
  
  The base definition for any payment instrument. It links the instrument to a specific Merchant configuration (handler_id) and defines common fields like billing address.
  
  Generated from: payment_instrument_base.json
  """
  import Ecto.Changeset

  @fields [
    %{
      name: :billing_address,
      type:
        Schemecto.one(Bazaar.Schemas.Shopping.Types.PostalAddress.fields(),
          with: &Function.identity/1
        ),
      description: "The billing address associated with this payment method."
    },
    %{name: :credential, type: :map},
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
    %{
      name: :type,
      type: :string,
      description:
        "The broad category of the instrument (e.g., 'card', 'tokenized_card'). Specific schemas will constrain this to a constant value."
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:id, :handler_id, :type])
  end
end