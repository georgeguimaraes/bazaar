defmodule Bazaar.Schemas.Acp.ProductFeedTest do
  use ExUnit.Case, async: true

  alias Bazaar.Schemas.Acp.ProductFeed

  @valid_attrs %{
    item_id: "SKU-12345",
    title: "Classic Leather Jacket",
    description: "Premium full-grain leather jacket with quilted lining.",
    url: "https://shop.example.com/products/classic-leather-jacket",
    brand: "Heritage Co.",
    image_url: "https://cdn.example.com/images/jacket-main.jpg",
    price: "129.99 USD",
    availability: :in_stock,
    is_eligible_search: true,
    is_eligible_checkout: false,
    group_id: "SKU-12345",
    listing_has_variations: false,
    seller_name: "Heritage Co. Official Store",
    seller_url: "https://shop.example.com",
    target_countries: ["US"],
    store_country: "US",
    return_policy: "https://shop.example.com/returns"
  }

  describe "changeset/2 with valid data" do
    test "valid with all required fields" do
      changeset = ProductFeed.changeset(%ProductFeed{}, @valid_attrs)
      assert changeset.valid?
    end

    test "valid with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          additional_image_urls: [
            "https://cdn.example.com/images/jacket-side.jpg",
            "https://cdn.example.com/images/jacket-back.jpg"
          ],
          star_rating: "4.5",
          review_count: 312,
          condition: "new",
          gtin: "00012345678905",
          mpn: "HLC-2024-BLK",
          sale_price: "99.99 USD",
          product_category: "Apparel > Jackets > Leather",
          color: "Black",
          size: "L",
          popularity_score: 4.2,
          seller_privacy_policy: "https://shop.example.com/privacy",
          seller_tos: "https://shop.example.com/tos",
          availability_date: "2026-06-01"
        })

      changeset = ProductFeed.changeset(%ProductFeed{}, attrs)
      assert changeset.valid?
    end
  end

  describe "changeset/2 with missing required fields" do
    test "invalid when all required fields missing" do
      changeset = ProductFeed.changeset(%ProductFeed{}, %{})
      refute changeset.valid?

      required = [
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

      for field <- required do
        assert {_, [validation: :required]} = changeset.errors[field]
      end
    end
  end

  describe "changeset/2 with invalid enum" do
    test "rejects invalid availability value" do
      attrs = Map.put(@valid_attrs, :availability, :maybe_in_stock)
      changeset = ProductFeed.changeset(%ProductFeed{}, attrs)
      refute changeset.valid?
      assert changeset.errors[:availability]
    end
  end

  describe "changeset/2 with invalid price format" do
    test "rejects price missing currency code" do
      attrs = Map.put(@valid_attrs, :price, "129.99")
      changeset = ProductFeed.changeset(%ProductFeed{}, attrs)
      refute changeset.valid?
      assert {_, [validation: :format]} = changeset.errors[:price]
    end

    test "rejects price with lowercase currency" do
      attrs = Map.put(@valid_attrs, :price, "129.99 usd")
      changeset = ProductFeed.changeset(%ProductFeed{}, attrs)
      refute changeset.valid?
      assert {_, [validation: :format]} = changeset.errors[:price]
    end

    test "rejects sale_price with invalid format" do
      attrs = Map.merge(@valid_attrs, %{sale_price: "free"})
      changeset = ProductFeed.changeset(%ProductFeed{}, attrs)
      refute changeset.valid?
      assert {_, [validation: :format]} = changeset.errors[:sale_price]
    end
  end

  describe "conditional: is_eligible_checkout" do
    test "invalid without policies when is_eligible_checkout=true" do
      attrs =
        @valid_attrs
        |> Map.put(:is_eligible_checkout, true)
        |> Map.delete(:return_policy)

      changeset = ProductFeed.changeset(%ProductFeed{}, attrs)
      refute changeset.valid?
      assert changeset.errors[:seller_privacy_policy]
      assert changeset.errors[:seller_tos]
      assert changeset.errors[:return_policy]
    end

    test "valid with policies when is_eligible_checkout=true" do
      attrs =
        @valid_attrs
        |> Map.put(:is_eligible_checkout, true)
        |> Map.put(:seller_privacy_policy, "https://shop.example.com/privacy")
        |> Map.put(:seller_tos, "https://shop.example.com/tos")

      changeset = ProductFeed.changeset(%ProductFeed{}, attrs)
      assert changeset.valid?
    end

    test "return_policy not required when is_eligible_checkout=false" do
      attrs = Map.delete(@valid_attrs, :return_policy)
      changeset = ProductFeed.changeset(%ProductFeed{}, attrs)
      assert changeset.valid?
    end
  end

  describe "conditional: availability=pre_order" do
    test "invalid without availability_date when pre_order" do
      attrs = Map.put(@valid_attrs, :availability, :pre_order)
      changeset = ProductFeed.changeset(%ProductFeed{}, attrs)
      refute changeset.valid?
      assert changeset.errors[:availability_date]
    end

    test "valid with availability_date when pre_order" do
      attrs =
        @valid_attrs
        |> Map.put(:availability, :pre_order)
        |> Map.put(:availability_date, "2026-06-01")

      changeset = ProductFeed.changeset(%ProductFeed{}, attrs)
      assert changeset.valid?
    end
  end

  describe "new/1" do
    test "creates a changeset from params" do
      changeset = ProductFeed.new(@valid_attrs)
      assert changeset.valid?
    end
  end
end
