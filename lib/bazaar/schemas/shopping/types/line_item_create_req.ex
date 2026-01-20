defmodule Bazaar.Schemas.Shopping.Types.LineItemCreateReq do
  @moduledoc """
  Line Item Create Request
  
  Line item object. Expected to use the currency of the parent object.
  
  Generated from: line_item.create_req.json
  """
  import Ecto.Changeset

  @fields [
    %{
      name: :item,
      type:
        Schemecto.one(Bazaar.Schemas.Shopping.Types.ItemCreateReq.fields(),
          with: &Function.identity/1
        )
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