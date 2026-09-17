defmodule Bazaar.Schemas.Shopping.Types.ItemUpdateReq do
  @moduledoc """
  Item Update Request

  Generated from: item.update_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.QuantityUnit

  @field_descriptions %{
    id:
      "The product identifier, often the SKU, required to resolve the product details associated with this line item. Should be recognized by both the Platform, and the Business.",
    quantity_unit:
      "Sale basis this item's `quantity` is denominated in. On an authoritative Business response, absence encodes the default `each` machine identity (`C62`, 0); the Business MUST include this descriptor for every non-`each` response. On Platform requests, omission makes no assertion: the Business interprets `quantity` using the item's authoritative sale basis. If the Platform includes this descriptor, it asserts the unit-descriptor machine identity. The Business MUST compare that machine identity (`unit`, effective `scale`), ignore `display_text` and `increment`, and resolve a mismatch by conversion surfaced as a visible line revision with a warning, or by rejection with a recoverable business outcome; silent reinterpretation is forbidden. An explicit `C62` descriptor at effective scale 0 matches an authoritative basis represented by an absent descriptor."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    embeds_one(:quantity_unit, QuantityUnit)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:id])
    |> cast_embed(:quantity_unit, required: false)
    |> validate_required([:id])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
