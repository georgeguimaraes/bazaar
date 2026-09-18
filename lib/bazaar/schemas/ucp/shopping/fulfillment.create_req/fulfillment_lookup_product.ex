defmodule Bazaar.Schemas.Shopping.FulfillmentCreateReq.FulfillmentLookupProduct do
  @moduledoc """
  Product

  A lookup product whose variants are fulfillment-enriched, preserving input correlation. Used by lookup.

  Generated from: fulfillment.create_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Description
  alias Bazaar.Schemas.Common.Types.Media
  alias Bazaar.Schemas.Common.Types.PriceRange
  alias Bazaar.Schemas.Shopping.FulfillmentCreateReq.FulfillmentLookupVariant
  alias Bazaar.Schemas.Shopping.Types.Category
  alias Bazaar.Schemas.Shopping.Types.ProductOption
  alias Bazaar.Schemas.Shopping.Types.Rating

  @field_descriptions %{
    categories: "Product categories with optional taxonomy identifiers.",
    description: "Product description in one or more formats.",
    handle:
      "URL-safe slug for SEO-friendly URLs (e.g., 'blue-runner-pro'). Use id for stable API references.",
    id: "Global ID (GID) uniquely identifying this product.",
    list_price_range: "List price range before discounts (for strikethrough display).",
    media:
      "Product media (images, videos, 3D models). First item is the featured media for listings.",
    metadata: "Business-defined custom data extending the standard product model.",
    options: "Product options (Size, Color, etc.).",
    price_range: "Price range across all variants.",
    rating: "Aggregate product rating.",
    tags: "Product tags for categorization and search.",
    title: "Product title.",
    url: "Canonical product page URL.",
    variants:
      "Purchasable variants of this product. First item is the featured variant for listings."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:handle, :string)
    field(:id, :string)
    field(:metadata, :map)
    field(:tags, {:array, :string})
    field(:title, :string)
    field(:url, :string)
    embeds_many(:categories, Category)
    embeds_one(:description, Description)
    embeds_one(:list_price_range, PriceRange)
    embeds_many(:media, Media)
    embeds_many(:options, ProductOption)
    embeds_one(:price_range, PriceRange)
    embeds_one(:rating, Rating)
    embeds_many(:variants, FulfillmentLookupVariant)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:handle, :id, :metadata, :tags, :title, :url])
    |> cast_embed(:categories, required: false)
    |> cast_embed(:description, required: true)
    |> cast_embed(:list_price_range, required: false)
    |> cast_embed(:media, required: false)
    |> cast_embed(:options, required: false)
    |> cast_embed(:price_range, required: true)
    |> cast_embed(:rating, required: false)
    |> cast_embed(:variants, required: true)
    |> validate_required([:id, :title])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
