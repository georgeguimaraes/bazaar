defmodule Bazaar.Schemas.Shopping.Types.FulfillmentGroupCreateReq do
  @moduledoc """
  Fulfillment Group Create Request
  
  A merchant-generated package/group of line items with fulfillment options.
  
  Generated from: fulfillment_group.create_req.json
  """
  @fields [
    %{
      name: :selected_option_id,
      type: :string,
      description: "ID of the selected fulfillment option for this group."
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