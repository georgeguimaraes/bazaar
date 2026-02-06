defmodule Bazaar.Validator.ProductFeedTest do
  use ExUnit.Case, async: true

  alias Bazaar.Validator

  @valid_product_feed %{
    "item_id" => "SKU-12345",
    "title" => "Classic Leather Jacket",
    "description" => "Premium full-grain leather jacket with quilted lining.",
    "url" => "https://shop.example.com/products/classic-leather-jacket",
    "brand" => "Heritage Co.",
    "image_url" => "https://cdn.example.com/images/jacket-main.jpg",
    "price" => "129.99 USD",
    "availability" => "in_stock",
    "is_eligible_search" => true,
    "is_eligible_checkout" => false,
    "group_id" => "SKU-12345",
    "listing_has_variations" => false,
    "seller_name" => "Heritage Co. Official Store",
    "seller_url" => "https://shop.example.com",
    "target_countries" => ["US"],
    "store_country" => "US",
    "return_policy" => "https://shop.example.com/returns"
  }

  describe "schema metadata" do
    test "includes :product_feed in available_schemas" do
      assert :product_feed in Validator.available_schemas()
    end

    test "returns product_feed schema with correct metadata" do
      assert {:ok, schema} = Validator.get_schema(:product_feed)

      assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
      assert schema["title"] == "OpenAI Product Feed"
      assert is_map(schema["properties"])
      assert is_list(schema["required"])
      assert length(schema["required"]) == 17
    end
  end

  describe "validate_product_feed/1" do
    test "validates a minimal valid product feed (required fields only)" do
      assert {:ok, _} = Validator.validate_product_feed(@valid_product_feed)
    end

    test "validates a product feed with commonly used optional fields" do
      full =
        Map.merge(@valid_product_feed, %{
          "additional_image_urls" => [
            "https://cdn.example.com/images/jacket-side.jpg",
            "https://cdn.example.com/images/jacket-back.jpg"
          ],
          "star_rating" => "4.5",
          "review_count" => 312,
          "condition" => "new",
          "gtin" => "00012345678905",
          "mpn" => "HLC-2024-BLK",
          "sale_price" => "99.99 USD",
          "product_category" => "Apparel > Jackets > Leather",
          "color" => "Black",
          "size" => "L",
          "popularity_score" => 4.2
        })

      assert {:ok, _} = Validator.validate_product_feed(full)
    end
  end

  describe "required field validation" do
    test "rejects empty data (all required fields missing)" do
      assert {:error, errors} = Validator.validate_product_feed(%{})
      assert is_list(errors) or is_map(errors)
    end

    test "rejects data missing a single required field (item_id)" do
      data = Map.delete(@valid_product_feed, "item_id")
      assert {:error, _} = Validator.validate_product_feed(data)
    end

    test "rejects data missing seller_name" do
      data = Map.delete(@valid_product_feed, "seller_name")
      assert {:error, _} = Validator.validate_product_feed(data)
    end

    test "rejects data missing return_policy" do
      data = Map.delete(@valid_product_feed, "return_policy")
      assert {:error, _} = Validator.validate_product_feed(data)
    end
  end

  describe "field value validation" do
    test "rejects non-string url" do
      data = Map.put(@valid_product_feed, "url", 12345)
      assert {:error, _} = Validator.validate_product_feed(data)
    end

    test "rejects non-string image_url" do
      data = Map.put(@valid_product_feed, "image_url", true)
      assert {:error, _} = Validator.validate_product_feed(data)
    end

    test "rejects invalid price format (missing currency)" do
      data = Map.put(@valid_product_feed, "price", "129.99")
      assert {:error, _} = Validator.validate_product_feed(data)
    end

    test "rejects price with lowercase currency" do
      data = Map.put(@valid_product_feed, "price", "129.99 usd")
      assert {:error, _} = Validator.validate_product_feed(data)
    end

    test "rejects invalid availability enum" do
      data = Map.put(@valid_product_feed, "availability", "maybe_in_stock")
      assert {:error, _} = Validator.validate_product_feed(data)
    end

    test "rejects empty target_countries" do
      data = Map.put(@valid_product_feed, "target_countries", [])
      assert {:error, _} = Validator.validate_product_feed(data)
    end

    test "rejects invalid gtin (non-numeric)" do
      data = Map.put(@valid_product_feed, "gtin", "ABC123")
      assert {:error, _} = Validator.validate_product_feed(data)
    end
  end

  describe "additional properties" do
    test "rejects unknown fields" do
      data = Map.put(@valid_product_feed, "unknown_field", "value")
      assert {:error, _} = Validator.validate_product_feed(data)
    end
  end

  describe "conditional requirements" do
    test "requires seller_privacy_policy and seller_tos when is_eligible_checkout=true" do
      data = Map.put(@valid_product_feed, "is_eligible_checkout", true)
      assert {:error, _} = Validator.validate_product_feed(data)
    end

    test "validates when is_eligible_checkout=true with policies provided" do
      data =
        @valid_product_feed
        |> Map.put("is_eligible_checkout", true)
        |> Map.put("seller_privacy_policy", "https://shop.example.com/privacy")
        |> Map.put("seller_tos", "https://shop.example.com/tos")

      assert {:ok, _} = Validator.validate_product_feed(data)
    end

    test "requires availability_date when availability=pre_order" do
      data = Map.put(@valid_product_feed, "availability", "pre_order")
      assert {:error, _} = Validator.validate_product_feed(data)
    end

    test "validates when availability=pre_order with availability_date provided" do
      data =
        @valid_product_feed
        |> Map.put("availability", "pre_order")
        |> Map.put("availability_date", "2026-06-01")

      assert {:ok, _} = Validator.validate_product_feed(data)
    end
  end

  describe "validate/2 with :product_feed" do
    test "validates via generic validate/2" do
      assert {:ok, _} = Validator.validate(@valid_product_feed, :product_feed)
    end

    test "returns errors via generic validate/2" do
      assert {:error, _} = Validator.validate(%{}, :product_feed)
    end
  end
end
