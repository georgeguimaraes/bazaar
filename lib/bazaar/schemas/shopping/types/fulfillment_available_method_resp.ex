defmodule Bazaar.Schemas.Shopping.Types.FulfillmentAvailableMethodResp do
  @moduledoc """
  Fulfillment Available Method Response
  
  Inventory availability hint for a fulfillment method type.
  
  Generated from: fulfillment_available_method_resp.json
  """
  import Ecto.Changeset
  @type_values [:shipping, :pickup]
  @type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @type_values)
  @fields [
    %{
      name: :description,
      type: :string,
      description:
        "Human-readable availability info (e.g., 'Available for pickup at Downtown Store today')."
    },
    %{
      name: :fulfillable_on,
      type: :string,
      description:
        "'now' for immediate availability, or ISO 8601 date for future (preorders, transfers)."
    },
    %{
      name: :line_item_ids,
      type: {:array, :string},
      description: "Line items available for this fulfillment method."
    },
    %{
      name: :type,
      type: @type_type,
      description: "Fulfillment method type this availability applies to."
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:type, :line_item_ids])
  end
end