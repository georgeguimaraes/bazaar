defmodule Bazaar.Schemas.Shopping.PaymentResp do
  @moduledoc """
  Payment Response
  
  Payment configuration containing handlers.
  
  Generated from: payment_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Types.PaymentHandlerResp

  @field_descriptions %{
    handlers:
      "Processing configurations that define how payment instruments can be collected. Each handler specifies a tokenization or payment collection strategy.",
    instruments:
      "The payment instruments available for this payment. Each instrument is associated with a specific handler via the handler_id field. Handlers can extend the base payment_instrument schema to add handler-specific fields.",
    selected_instrument_id:
      "The id of the currently selected payment instrument from the instruments array. Set by the agent when submitting payment, and echoed back by the merchant in finalized state."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:instruments, {:array, :map})
    field(:selected_instrument_id, :string)
    embeds_many(:handlers, PaymentHandlerResp)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:instruments, :selected_instrument_id])
    |> cast_embed(:handlers, required: true)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
