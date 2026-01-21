defmodule Bazaar.Schemas.Shopping.Types.FulfillmentReq do
  @moduledoc """
  Fulfillment Request
  
  Container for fulfillment methods and availability.
  
  Generated from: fulfillment_req.json
  """
  @fields [
    %{
      name: :methods,
      type:
        Schemecto.many(Bazaar.Schemas.Shopping.Types.FulfillmentMethodCreateReq.fields(),
          with: &Function.identity/1
        ),
      description: "Fulfillment methods for cart items."
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params)
  end
end