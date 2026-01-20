defmodule Bazaar.Schemas.Shopping.Types.FulfillmentMethodResp do
  @moduledoc """
  Fulfillment Method Response
  
  A fulfillment method (shipping or pickup) with destinations and groups.
  
  Generated from: fulfillment_method_resp.json
  """
  import Ecto.Changeset
  @type_values [:shipping, :pickup]
  @type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @type_values)
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
        Schemecto.many(Bazaar.Schemas.Shopping.Types.FulfillmentGroupResp.fields(),
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
    },
    %{name: :type, type: @type_type, description: "Fulfillment method type."}
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:id, :type, :line_item_ids])
  end
end