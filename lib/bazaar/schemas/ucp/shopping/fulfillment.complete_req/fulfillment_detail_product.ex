defmodule Bazaar.Schemas.Shopping.FulfillmentCompleteReq.FulfillmentDetailProduct do
  @moduledoc """
  Product

  A get_product detail product (carrying selected/options availability signals) whose variants are fulfillment-enriched. Used by get_product.

  Generated from: fulfillment.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Description
  alias Bazaar.Schemas.Common.Types.Media
  alias Bazaar.Schemas.Common.Types.PriceRange
  alias Bazaar.Schemas.Shopping.FulfillmentCompleteReq.FulfillmentVariant
  alias Bazaar.Schemas.Shopping.Types.Category
  alias Bazaar.Schemas.Shopping.Types.ProductOption
  alias Bazaar.Schemas.Shopping.Types.Rating
  alias Bazaar.Schemas.Shopping.Types.SelectedOption
  @doc "Returns the description for a field, if available."
  def field_description(:categories) do
    "Product categories with optional taxonomy identifiers."
  end

  def field_description(:description) do
    "Product description in one or more formats."
  end

  def field_description(:handle) do
    "URL-safe slug for SEO-friendly URLs (e.g., 'blue-runner-pro'). Use id for stable API references."
  end

  def field_description(:id) do
    "Global ID (GID) uniquely identifying this product."
  end

  def field_description(:list_price_range) do
    "List price range before discounts (for strikethrough display)."
  end

  def field_description(:media) do
    "Product media (images, videos, 3D models). First item is the featured media for listings."
  end

  def field_description(:metadata) do
    "Business-defined custom data extending the standard product model."
  end

  def field_description(:options) do
    "Product options with availability signals relative to the effective selections."
  end

  def field_description(:price_range) do
    "Price range across all variants."
  end

  def field_description(:rating) do
    "Aggregate product rating."
  end

  def field_description(:selected) do
    "Effective option selections that anchor the featured variant and availability signals. Required when the product has configurable options; may be empty or omitted for products with no option axes."
  end

  def field_description(:tags) do
    "Product tags for categorization and search."
  end

  def field_description(:title) do
    "Product title."
  end

  def field_description(:url) do
    "Canonical product page URL."
  end

  def field_description(:variants) do
    "Purchasable variants of this product. First item is the featured variant for listings."
  end

  def field_description(field) when is_atom(field) do
    nil
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
    embeds_many(:selected, SelectedOption)
    embeds_many(:variants, FulfillmentVariant)
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
    |> cast_embed(:selected, required: false)
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
