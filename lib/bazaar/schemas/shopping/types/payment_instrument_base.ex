defmodule Bazaar.Schemas.Shopping.Types.PaymentInstrumentBase do
  @moduledoc """
  Payment Instrument Base
  
  The base definition for any payment instrument. It links the instrument to a specific Merchant configuration (handler_id) and defines common fields like billing address.
  
  Generated from: payment_instrument_base.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Types.PostalAddress

  @field_descriptions %{
    billing_address: "The billing address associated with this payment method.",
    credential: nil,
    handler_id:
      "The unique identifier for the handler instance that produced this instrument. This corresponds to the 'id' field in the Payment Handler definition.",
    id:
      "A unique identifier for this instrument instance, assigned by the Agent. Used to reference this specific instrument in the 'payment.selected_instrument_id' field.",
    type:
      "The broad category of the instrument (e.g., 'card', 'tokenized_card'). Specific schemas will constrain this to a constant value."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:credential, :map)
    field(:handler_id, :string)
    field(:id, :string)
    field(:type, :string)
    embeds_one(:billing_address, PostalAddress)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:credential, :handler_id, :id, :type])
    |> cast_embed(:billing_address, required: false)
    |> validate_required([:id, :handler_id, :type])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end