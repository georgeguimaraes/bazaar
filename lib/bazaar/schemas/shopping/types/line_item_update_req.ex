defmodule Bazaar.Schemas.Shopping.Types.LineItemUpdateReq do
  @moduledoc """
  Line Item Update Request
  
  Line item object. Expected to use the currency of the parent object.
  
  Generated from: line_item.update_req.json
  """
  import Ecto.Changeset

  @fields [
    %{name: :id, type: :string},
    %{
      name: :item,
      type:
        Schemecto.one(Bazaar.Schemas.Shopping.Types.ItemUpdateReq.fields(),
          with: &Function.identity/1
        )
    },
    %{
      name: :parent_id,
      type: :string,
      description: "Parent line item identifier for any nested structures."
    },
    %{name: :quantity, type: :integer, description: "Quantity of the item being purchased."}
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:item, :quantity])
  end
end