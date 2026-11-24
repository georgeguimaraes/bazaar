defmodule Bazaar.Schemas.Shopping.Types.LineItemResp do
  @moduledoc """
  Line Item Response

  Line item object. Expected to use the currency of the parent object.

  Generated from: line_item_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.TotalResp
  alias Bazaar.Schemas.Shopping.Types.ItemResp
  @doc "Returns the description for a field, if available."
  def field_description(:id) do
    nil
  end

  def field_description(:item) do
    nil
  end

  def field_description(:parent_id) do
    "Parent line item identifier for any nested structures."
  end

  def field_description(:quantity) do
    "Always an integer step count. On Platform requests, steps use the item's Business-authoritative sale basis; omitting `item.quantity_unit` makes no assertion and does not imply `each`. On Business responses, `item.quantity_unit` describes the basis; if absent, it encodes the `each` machine identity (`C62`, 0) and `quantity` counts whole items."
  end

  def field_description(:totals) do
    "Line item totals breakdown."
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:parent_id, :string)
    field(:quantity, :integer)
    embeds_one(:item, ItemResp)
    embeds_many(:totals, TotalResp)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:id, :parent_id, :quantity])
    |> cast_embed(:item, required: true)
    |> cast_embed(:totals, required: true)
    |> validate_required([:id, :quantity])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
