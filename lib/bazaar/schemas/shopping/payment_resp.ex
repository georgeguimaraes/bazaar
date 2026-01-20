defmodule Bazaar.Schemas.Shopping.PaymentResp do
  @moduledoc """
  Payment Response
  
  Payment configuration containing handlers.
  
  Generated from: payment_resp.json
  """
  import Ecto.Changeset

  @fields [
    %{
      name: :handlers,
      type:
        Schemecto.many(Bazaar.Schemas.Shopping.Types.PaymentHandlerResp.fields(),
          with: &Function.identity/1
        ),
      description:
        "Processing configurations that define how payment instruments can be collected. Each handler specifies a tokenization or payment collection strategy."
    },
    %{
      name: :instruments,
      type: {:array, :map},
      description:
        "The payment instruments available for this payment. Each instrument is associated with a specific handler via the handler_id field. Handlers can extend the base payment_instrument schema to add handler-specific fields."
    },
    %{
      name: :selected_instrument_id,
      type: :string,
      description:
        "The id of the currently selected payment instrument from the instruments array. Set by the agent when submitting payment, and echoed back by the merchant in finalized state."
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:handlers])
  end
end