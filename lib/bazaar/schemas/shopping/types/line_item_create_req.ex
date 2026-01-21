defmodule Bazaar.Schemas.Shopping.Types.LineItemCreateReq do
  @moduledoc """
  Line Item Create Request
  
  Line item object. Expected to use the currency of the parent object.
  
  Generated from: line_item.create_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Types.ItemCreateReq
  @field_descriptions %{item: nil, quantity: "Quantity of the item being purchased."}
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:quantity, :integer)
    embeds_one(:item, ItemCreateReq)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:quantity])
    |> cast_embed(:item, required: true)
    |> validate_required([:quantity])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end