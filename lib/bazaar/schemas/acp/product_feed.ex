defmodule Bazaar.Schemas.Acp.ProductFeed do
  @moduledoc """
  OpenAI product feed schema.

  Based on the OpenAI developer docs product feed spec
  (developers.openai.com/commerce/specs/feed/). Not part of the open ACP standard,
  so we express it as a native Ecto embedded schema rather than generating from JSON.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @availability_values [:in_stock, :out_of_stock, :pre_order, :backorder, :unknown]
  @age_group_values [:newborn, :infant, :toddler, :kids, :adult]
  @pickup_method_values [:in_store, :reserve, :not_supported]

  @relationship_type_values [
    :part_of_set,
    :required_part,
    :often_bought_with,
    :substitute,
    :different_brand,
    :accessory
  ]

  @required_fields [
    :item_id,
    :title,
    :description,
    :url,
    :brand,
    :image_url,
    :price,
    :availability,
    :is_eligible_search,
    :is_eligible_checkout,
    :group_id,
    :listing_has_variations,
    :seller_name,
    :seller_url,
    :target_countries,
    :store_country
  ]

  @optional_fields [
    # Media
    :additional_image_urls,
    :video_url,
    :model_3d_url,
    # Price & promotions
    :sale_price,
    :sale_price_start_date,
    :sale_price_end_date,
    :unit_pricing_measure,
    :base_measure,
    :pricing_trend,
    # Item info
    :product_category,
    :condition,
    :material,
    :dimensions,
    :length,
    :width,
    :height,
    :dimensions_unit,
    :weight,
    :item_weight_unit,
    :age_group,
    :color,
    :size,
    :size_system,
    :gender,
    # Identifiers
    :gtin,
    :mpn,
    :offer_id,
    # Variants
    :item_group_title,
    :variant_dict,
    :custom_variant1_category,
    :custom_variant1_option,
    :custom_variant2_category,
    :custom_variant2_option,
    :custom_variant3_category,
    :custom_variant3_option,
    # Fulfillment
    :shipping,
    :is_digital,
    # Availability
    :availability_date,
    :expiration_date,
    :pickup_method,
    :pickup_sla,
    # Merchant
    :marketplace_seller,
    :seller_privacy_policy,
    :seller_tos,
    # Returns
    :return_policy,
    :accepts_returns,
    :return_deadline_in_days,
    :accepts_exchanges,
    # Performance signals
    :popularity_score,
    :return_rate,
    :star_rating,
    :review_count,
    :store_star_rating,
    :store_review_count,
    # Reviews & Q&A
    :q_and_a,
    :reviews,
    # Related products
    :related_product_id,
    :relationship_type,
    # Geo
    :geo_price,
    :geo_availability,
    # Compliance
    :warning,
    :warning_url,
    :age_restriction
  ]

  @all_fields @required_fields ++ @optional_fields

  @price_format ~r/^\d+\.\d{2}\s[A-Z]{3}$/

  @field_descriptions %{
    # Required
    item_id: "Unique product identifier (alphanumeric, must remain stable).",
    title: "Product name/title.",
    description: "Product description (plain text).",
    url: "Direct link to the product page.",
    brand: "Brand name.",
    image_url: "Primary product image URL (JPEG/PNG).",
    price: "Price with ISO 4217 currency code, e.g. '129.99 USD'.",
    availability: "Stock status.",
    is_eligible_search: "Whether product appears in ChatGPT search results.",
    is_eligible_checkout:
      "Whether product supports direct AI checkout. Requires is_eligible_search=true.",
    group_id: "Product group ID for variants. Must match across variants.",
    listing_has_variations: "Whether product has size/color/etc variants.",
    seller_name: "Display name of the seller/merchant.",
    seller_url: "Base URL of the seller website.",
    target_countries: "Target market countries (ISO 3166-1 alpha-2 codes).",
    store_country: "Store location country (ISO 3166-1 alpha-2).",
    return_policy: "URL to the return policy page.",
    # Media
    additional_image_urls: "Additional product images.",
    video_url: "Product video URL.",
    model_3d_url: "3D model URL (GLB/GLTF preferred).",
    # Price & promotions
    sale_price: "Sale price with ISO 4217 currency code. Must be <= price.",
    sale_price_start_date: "Sale start date (ISO 8601).",
    sale_price_end_date: "Sale end date (ISO 8601).",
    unit_pricing_measure: "Unit pricing measure (number + unit). Required with base_measure.",
    base_measure: "Base measure for unit pricing. Required with unit_pricing_measure.",
    pricing_trend: "Pricing trend indicator.",
    # Item info
    product_category: "Product category taxonomy path (use '>' separator).",
    condition: "Product condition, e.g. 'new', 'refurbished'.",
    material: "Product material.",
    dimensions: "Product dimensions (format: LxWxH unit).",
    length: "Product length. Use with dimensions_unit.",
    width: "Product width. Use with dimensions_unit.",
    height: "Product height. Use with dimensions_unit.",
    dimensions_unit: "Dimensions unit abbreviation (e.g. 'in', 'cm').",
    weight: "Product weight. Use with item_weight_unit.",
    item_weight_unit: "Weight unit abbreviation (e.g. 'lb', 'kg').",
    age_group: "Target age group.",
    color: "Product color.",
    size: "Product size.",
    size_system: "Size system country code (ISO 3166-1 alpha-2).",
    gender: "Target gender (lowercase).",
    # Identifiers
    gtin: "GTIN/UPC/ISBN (8-14 digits).",
    mpn: "Manufacturer part number.",
    offer_id: "Unique offer ID within the feed.",
    # Variants
    item_group_title: "Title for the product group.",
    variant_dict: "Variant attributes as key-value pairs.",
    custom_variant1_category: "Custom variant dimension 1 label.",
    custom_variant1_option: "Custom variant dimension 1 value.",
    custom_variant2_category: "Custom variant dimension 2 label.",
    custom_variant2_option: "Custom variant dimension 2 value.",
    custom_variant3_category: "Custom variant dimension 3 label.",
    custom_variant3_option: "Custom variant dimension 3 value.",
    # Fulfillment
    shipping: "Shipping info (format: country:region:service:price:handling:transit).",
    is_digital: "Whether the product is digital/non-physical.",
    # Availability
    availability_date: "Expected availability date. Required when availability=pre_order.",
    expiration_date: "Product expiration date (ISO 8601).",
    pickup_method: "In-store pickup method.",
    pickup_sla: "Pickup service level agreement (time to ready).",
    # Merchant
    marketplace_seller: "Marketplace seller name (for multi-seller marketplaces).",
    seller_privacy_policy:
      "URL to the seller privacy policy. Required when is_eligible_checkout=true.",
    seller_tos: "URL to the seller terms of service. Required when is_eligible_checkout=true.",
    # Returns
    accepts_returns: "Whether the product accepts returns.",
    return_deadline_in_days: "Number of days within which returns are accepted.",
    accepts_exchanges: "Whether the product accepts exchanges.",
    # Performance signals
    popularity_score: "Popularity score (0-5 scale or merchant-defined).",
    return_rate: "Return rate percentage (0-100).",
    star_rating: "Product rating as string, e.g. '4.5' (0-5 scale).",
    review_count: "Number of product reviews.",
    store_star_rating: "Store-level rating as string (0-5 scale).",
    store_review_count: "Number of store-level reviews.",
    # Reviews & Q&A
    q_and_a: "Product Q&A entries (list of {q, a} objects).",
    reviews: "Product review entries (list of review objects).",
    # Related products
    related_product_id: "Related product IDs (comma-separated).",
    relationship_type: "Relationship type to related product.",
    # Geo
    geo_price: "Region-specific pricing with ISO 4217 currency code.",
    geo_availability: "Region-specific availability (ISO 3166 region codes).",
    # Compliance
    warning: "Regulatory warning/disclaimer text.",
    warning_url: "URL to regulatory warning details.",
    age_restriction: "Minimum age restriction."
  }

  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    # Required: OpenAI flags
    field(:is_eligible_search, :boolean)
    field(:is_eligible_checkout, :boolean)

    # Required: basic product data
    field(:item_id, :string)
    field(:title, :string)
    field(:description, :string)
    field(:url, :string)
    field(:brand, :string)

    # Required: availability & geo
    field(:availability, Ecto.Enum, values: @availability_values)
    field(:target_countries, {:array, :string})
    field(:store_country, :string)

    # Required: variants
    field(:group_id, :string)
    field(:listing_has_variations, :boolean)

    # Required: merchant & returns
    field(:seller_name, :string)
    field(:seller_url, :string)
    field(:return_policy, :string)

    # Required: price
    field(:price, :string)

    # Required: media
    field(:image_url, :string)

    # Optional: media
    field(:additional_image_urls, {:array, :string})
    field(:video_url, :string)
    field(:model_3d_url, :string)

    # Optional: price & promotions
    field(:sale_price, :string)
    field(:sale_price_start_date, :string)
    field(:sale_price_end_date, :string)
    field(:unit_pricing_measure, :string)
    field(:base_measure, :string)
    field(:pricing_trend, :string)

    # Optional: item info
    field(:product_category, :string)
    field(:condition, :string)
    field(:material, :string)
    field(:dimensions, :string)
    field(:length, :string)
    field(:width, :string)
    field(:height, :string)
    field(:dimensions_unit, :string)
    field(:weight, :string)
    field(:item_weight_unit, :string)
    field(:age_group, Ecto.Enum, values: @age_group_values)
    field(:color, :string)
    field(:size, :string)
    field(:size_system, :string)
    field(:gender, :string)

    # Optional: identifiers
    field(:gtin, :string)
    field(:mpn, :string)
    field(:offer_id, :string)

    # Optional: variants
    field(:item_group_title, :string)
    field(:variant_dict, :map)
    field(:custom_variant1_category, :string)
    field(:custom_variant1_option, :string)
    field(:custom_variant2_category, :string)
    field(:custom_variant2_option, :string)
    field(:custom_variant3_category, :string)
    field(:custom_variant3_option, :string)

    # Optional: fulfillment
    field(:shipping, :string)
    field(:is_digital, :boolean)

    # Optional: availability
    field(:availability_date, :string)
    field(:expiration_date, :string)
    field(:pickup_method, Ecto.Enum, values: @pickup_method_values)
    field(:pickup_sla, :string)

    # Optional: merchant
    field(:marketplace_seller, :string)
    field(:seller_privacy_policy, :string)
    field(:seller_tos, :string)

    # Optional: returns
    field(:accepts_returns, :boolean)
    field(:return_deadline_in_days, :integer)
    field(:accepts_exchanges, :boolean)

    # Optional: performance signals
    field(:popularity_score, :float)
    field(:return_rate, :float)
    field(:star_rating, :string)
    field(:review_count, :integer)
    field(:store_star_rating, :string)
    field(:store_review_count, :integer)

    # Optional: reviews & Q&A
    field(:q_and_a, {:array, :map})
    field(:reviews, {:array, :map})

    # Optional: related products
    field(:related_product_id, :string)
    field(:relationship_type, Ecto.Enum, values: @relationship_type_values)

    # Optional: geo
    field(:geo_price, :string)
    field(:geo_availability, :string)

    # Optional: compliance
    field(:warning, :string)
    field(:warning_url, :string)
    field(:age_restriction, :integer)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, @all_fields)
    |> validate_required(@required_fields)
    |> validate_format(:price, @price_format)
    |> validate_format(:sale_price, @price_format)
    |> validate_checkout_policies()
    |> validate_pre_order_date()
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    changeset(params)
  end

  defp validate_checkout_policies(changeset) do
    if get_field(changeset, :is_eligible_checkout) == true do
      changeset
      |> validate_required([:seller_privacy_policy, :seller_tos, :return_policy])
    else
      changeset
    end
  end

  defp validate_pre_order_date(changeset) do
    if get_field(changeset, :availability) == :pre_order do
      changeset
      |> validate_required([:availability_date])
    else
      changeset
    end
  end
end
