defmodule Bazaar.Schemas.Shopping.Types.FulfillmentOptionReq do
  @moduledoc """
  Fulfillment Option Request
  
  A fulfillment option within a group (e.g., Standard Shipping $5, Express $15).
  
  Generated from: fulfillment_option_req.json
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