defmodule Bazaar.Schemas.Shopping.Types.FulfillmentMethodUpdateReq do
  @moduledoc """
  Fulfillment Method Update Request
  
  A fulfillment method (shipping or pickup) with destinations and groups.
  
  Generated from: fulfillment_method.update_req.json
  """
  import Ecto.Changeset

  @fields [
    %{
      name: :destinations,
      type: {:array, :map},
      description:
        "Available destinations. For shipping: addresses. For pickup: retail locations."
    },
    %{
      name: :groups,
      type:
        Schemecto.many(Bazaar.Schemas.Shopping.Types.FulfillmentGroupUpdateReq.fields(),
          with: &Function.identity/1
        ),
      description:
        "Fulfillment groups for selecting options. Agent sets selected_option_id on groups to choose shipping method."
    },
    %{name: :id, type: :string, description: "Unique fulfillment method identifier."},
    %{
      name: :line_item_ids,
      type: {:array, :string},
      description: "Line item IDs fulfilled via this method."
    },
    %{
      name: :selected_destination_id,
      type: :string,
      description: "ID of the selected destination."
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