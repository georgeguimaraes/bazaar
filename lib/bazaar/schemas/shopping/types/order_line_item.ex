defmodule Bazaar.Schemas.Shopping.Types.OrderLineItem do
  @moduledoc """
  Order Line Item
  
  Generated from: order_line_item.json
  """
  import Ecto.Changeset
  @status_values [:processing, :partial, :fulfilled]
  @status_type Ecto.ParameterizedType.init(Ecto.Enum, values: @status_values)
  @fields [
    %{name: :id, type: :string, description: "Line item identifier."},
    %{
      name: :item,
      type:
        Schemecto.one(Bazaar.Schemas.Shopping.Types.ItemResp.fields(), with: &Function.identity/1),
      description: "Product data (id, title, price, image_url)."
    },
    %{
      name: :parent_id,
      type: :string,
      description: "Parent line item identifier for any nested structures."
    },
    %{
      name: :quantity,
      type: :map,
      description: "Quantity tracking. Both total and fulfilled are derived from events."
    },
    %{
      name: :status,
      type: @status_type,
      description:
        "Derived status: fulfilled if quantity.fulfilled == quantity.total, partial if quantity.fulfilled > 0, otherwise processing."
    },
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
    Schemecto.new(@fields, params) |> validate_required([:id, :item, :quantity, :totals, :status])
  end
end