defmodule Bazaar.Schemas.Shopping.Types.FulfillmentAvailableMethodReq do
  @moduledoc """
  Fulfillment Available Method Request
  
  Inventory availability hint for a fulfillment method type.
  
  Generated from: fulfillment_available_method_req.json
  """
  import Ecto.Changeset
  @fields []
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params)
  end
end