defmodule Bazaar.Schemas.Shopping.Payment do
  @moduledoc """
  Payment

  Payment configuration containing handlers.

  Generated from: payment.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Types.PaymentInstrument.SelectedPaymentInstrument

  @field_descriptions %{
    instruments:
      "The payment instruments available for this payment. Each instrument is associated with a specific handler via the handler_id field. Handlers can extend the base payment_instrument schema to add handler-specific fields."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    embeds_many(:instruments, SelectedPaymentInstrument)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, []) |> cast_embed(:instruments, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
