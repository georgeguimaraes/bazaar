defmodule Bazaar.Schemas.Shopping.Types.FulfillmentGroupResp do
  @moduledoc """
  Fulfillment Group Response
  
  A merchant-generated package/group of line items with fulfillment options.
  
  Generated from: fulfillment_group_resp.json
  """
  import Ecto.Changeset

  @fields [
    %{
      name: :id,
      type: :string,
      description: "Group identifier for referencing merchant-generated groups in updates."
    },
    %{
      name: :line_item_ids,
      type: {:array, :string},
      description: "Line item IDs included in this group/package."
    },
    %{
      name: :options,
      type:
        Schemecto.many(Bazaar.Schemas.Shopping.Types.FulfillmentOptionResp.fields(),
          with: &Function.identity/1
        ),
      description: "Available fulfillment options for this group."
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
    Schemecto.new(@fields, params) |> validate_required([:id, :line_item_ids])
  end
end