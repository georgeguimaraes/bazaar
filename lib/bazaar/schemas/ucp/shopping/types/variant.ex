defmodule Bazaar.Schemas.Shopping.Types.Variant do
  @moduledoc """
  Variant

  A purchasable variant of a product with specific option selections.

  Generated from: variant.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Description
  alias Bazaar.Schemas.Common.Types.Media
  alias Bazaar.Schemas.Common.Types.Price
  alias Bazaar.Schemas.Common.Types.QuantityUnit
  alias Bazaar.Schemas.Shopping.Types.Availability
  alias Bazaar.Schemas.Shopping.Types.Category
  alias Bazaar.Schemas.Shopping.Types.Rating
  alias Bazaar.Schemas.Shopping.Types.SelectedOption
  alias Bazaar.Schemas.Shopping.Types.UnitPrice

  @field_descriptions %{
    availability: "Variant availability for purchase.",
    barcodes: "Industry-standard product identifiers for cross-reference and correlation.",
    categories: "Variant categories with optional taxonomy identifiers.",
    description: "Variant description in one or more formats.",
    handle: "URL-safe variant handle/slug.",
    id: "Global ID (GID) uniquely identifying this variant. Used as item.id in checkout.",
    list_price: "List price before discounts (for strikethrough display).",
    media:
      "Variant media (images, videos, 3D models). First item is the featured media for listings.",
    metadata: "Business-defined custom data extending the standard variant model.",
    options: "Option values that define this variant (e.g., Color: Blue, Size: Large).",
    price:
      "Current selling price. Price is the amount per one whole `quantity_unit.unit` (for example, per lb or per hour); when `quantity_unit` is absent, it is per `each`. Line total is `price × quantity × 10^-scale`, computed and rounded once by the Business; `totals` remain authoritative.",
    quantity_unit:
      "Sale basis this variant's `quantity` is denominated in. The default sale basis is `each`, whose machine identity is (`C62`, 0); `C62` is the UN/CEFACT Rec20 code for one/each. An absent catalog descriptor encodes that default. An `increment` advertises the ordering granularity in steps (for example, `scale` 2 with `increment` 25 sells in 0.25-unit multiples).",
    rating: "Variant rating.",
    seller: "Optional seller context for this variant.",
    sku: "Business-assigned identifier for inventory and fulfillment.",
    tags: "Variant tags for categorization and search.",
    title: "Variant display title (e.g., 'Blue / Large').",
    unit_price:
      "Price per standard unit of measurement, for shelf-style comparison display. MAY be omitted when unit pricing does not apply.",
    url: "Canonical variant page URL."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:barcodes, {:array, :map})
    field(:handle, :string)
    field(:id, :string)
    field(:metadata, :map)
    field(:seller, :map)
    field(:sku, :string)
    field(:tags, {:array, :map})
    field(:title, :string)
    field(:url, :string)
    embeds_one(:availability, Availability)
    embeds_many(:categories, Category)
    embeds_one(:description, Description)
    embeds_one(:list_price, Price)
    embeds_many(:media, Media)
    embeds_many(:options, SelectedOption)
    embeds_one(:price, Price)
    embeds_one(:quantity_unit, QuantityUnit)
    embeds_one(:rating, Rating)
    embeds_one(:unit_price, UnitPrice)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:barcodes, :handle, :id, :metadata, :seller, :sku, :tags, :title, :url])
    |> cast_embed(:availability, required: false)
    |> cast_embed(:categories, required: false)
    |> cast_embed(:description, required: true)
    |> cast_embed(:list_price, required: false)
    |> cast_embed(:media, required: false)
    |> cast_embed(:options, required: false)
    |> cast_embed(:price, required: true)
    |> cast_embed(:quantity_unit, required: false)
    |> cast_embed(:rating, required: false)
    |> cast_embed(:unit_price, required: false)
    |> validate_required([:id, :title])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
