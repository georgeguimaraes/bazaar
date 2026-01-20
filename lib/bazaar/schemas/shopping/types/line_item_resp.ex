defmodule Bazaar.Schemas.Shopping.Types.LineItemResp do
  @moduledoc """
  Line Item Response
  
  Line item object. Expected to use the currency of the parent object.
  
  Generated from: line_item_resp.json
  """
  import Ecto.Changeset

  @fields [
    %{name: :id, type: :string},
    %{
      name: :item,
      type:
        Schemecto.one(Bazaar.Schemas.Shopping.Types.ItemResp.fields(), with: &Function.identity/1)
    },
    %{
      name: :parent_id,
      type: :string,
      description: "Parent line item identifier for any nested structures."
    },
    %{name: :quantity, type: :integer, description: "Quantity of the item being purchased."},
    %{
      name: :totals,
      type:
        Schemecto.many(Bazaar.Schemas.Shopping.Types.TotalResp.fields(),
          with: &Function.identity/1
        ),
      description: "Line item totals breakdown."
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:id, :item, :quantity, :totals])
  end
end