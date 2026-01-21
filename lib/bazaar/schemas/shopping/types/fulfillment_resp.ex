defmodule Bazaar.Schemas.Shopping.Types.FulfillmentResp do
  @moduledoc """
  Fulfillment Response
  
  Container for fulfillment methods and availability.
  
  Generated from: fulfillment_resp.json
  """
  @fields [
    %{
      name: :available_methods,
      type:
        Schemecto.many(Bazaar.Schemas.Shopping.Types.FulfillmentAvailableMethodResp.fields(),
          with: &Function.identity/1
        ),
      description: "Inventory availability hints."
    },
    %{
      name: :methods,
      type:
        Schemecto.many(Bazaar.Schemas.Shopping.Types.FulfillmentMethodResp.fields(),
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