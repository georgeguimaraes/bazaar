defmodule Bazaar.Schemas.Shopping.Types.FulfillmentGroupUpdateReq do
  @moduledoc """
  Fulfillment Group Update Request
  
  A merchant-generated package/group of line items with fulfillment options.
  
  Generated from: fulfillment_group.update_req.json
  """
  import Ecto.Changeset

  @fields [
    %{
      name: :id,
      type: :string,
      description: "Group identifier for referencing merchant-generated groups in updates."
    },
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
    Schemecto.new(@fields, params) |> validate_required([:id])
  end
end