defmodule Bazaar.Schemas.Shopping.Types.ItemResp do
  @moduledoc """
  Item Response

  Generated from: item_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.QuantityUnit
  alias Bazaar.Schemas.Shopping.Types.UnitPrice

  @field_descriptions %{
    id:
      "The product identifier, often the SKU, required to resolve the product details associated with this line item. Should be recognized by both the Platform, and the Business.",
    image_url: "Product image URI.",
    price:
      "Unit price in ISO 4217 minor units. Price is the amount per one whole `quantity_unit.unit` (for example, per lb or per hour); when `quantity_unit` is absent, it is per `each`.",
    quantity_unit:
      "Sale basis this item's `quantity` is denominated in. On an authoritative Business response, absence encodes the default `each` machine identity (`C62`, 0); the Business MUST include this descriptor for every non-`each` response. On Platform requests, omission makes no assertion: the Business interprets `quantity` using the item's authoritative sale basis. If the Platform includes this descriptor, it asserts the unit-descriptor machine identity. The Business MUST compare that machine identity (`unit`, effective `scale`), ignore `display_text` and `increment`, and resolve a mismatch by conversion surfaced as a visible line revision with a warning, or by rejection with a recoverable business outcome; silent reinterpretation is forbidden. An explicit `C62` descriptor at effective scale 0 matches an authoritative basis represented by an absent descriptor.",
    title: "Product title.",
    unit_price:
      "Pricing basis for this item. On an authoritative Business response, the Business MUST include `unit_price` on every line whose pricing basis differs from its sale basis (for example, priced per pound but sold per `each`); presence on a line marks the rate as transactional rather than display-only. When the pricing basis is the sale basis, `item.price` fully denominates the charge and this field MAY be omitted."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:image_url, :string)
    field(:price, :integer)
    field(:title, :string)
    embeds_one(:quantity_unit, QuantityUnit)
    embeds_one(:unit_price, UnitPrice)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:id, :image_url, :price, :title])
    |> cast_embed(:quantity_unit, required: false)
    |> cast_embed(:unit_price, required: false)
    |> validate_required([:id, :title, :price])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
