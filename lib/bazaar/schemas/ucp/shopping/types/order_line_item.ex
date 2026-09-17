defmodule Bazaar.Schemas.Shopping.Types.OrderLineItem do
  @moduledoc """
  Order Line Item

  Generated from: order_line_item.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.TotalResp
  alias Bazaar.Schemas.Shopping.Types.ItemResp
  @status_values [:processing, :partial, :fulfilled, :removed]
  @field_descriptions %{
    id: "Line item identifier.",
    item: "Purchased item data, including identity, price, and sale basis.",
    parent_id: "Parent line item identifier for any nested structures.",
    quantity:
      "Tracks the line item's original, current active, and fulfilled quantities. All three values use the same inherited `item.quantity_unit`. When `item.quantity_unit` is absent on an authoritative order response, each step is one whole item (`each`) under the shared default.",
    status:
      "Derived status: removed if quantity.total == 0, fulfilled if quantity.total > 0 and quantity.fulfilled == quantity.total, partial if quantity.total > 0 and quantity.fulfilled > 0, otherwise processing.",
    totals: "Line item totals breakdown."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:parent_id, :string)
    field(:quantity, :map)
    field(:status, Ecto.Enum, values: @status_values)
    embeds_one(:item, ItemResp)
    embeds_many(:totals, TotalResp)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:id, :parent_id, :quantity, :status])
    |> cast_embed(:item, required: true)
    |> cast_embed(:totals, required: true)
    |> validate_required([:id, :quantity, :status])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
