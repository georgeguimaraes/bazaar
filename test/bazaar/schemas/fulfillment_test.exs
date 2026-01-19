defmodule Bazaar.Schemas.FulfillmentTest do
  use ExUnit.Case, async: true

  alias Bazaar.Schemas.Fulfillment

  describe "method_types/0" do
    test "returns supported method types" do
      types = Fulfillment.method_types()

      assert :shipping in types
      assert :pickup in types
    end
  end

  describe "destination_types/0" do
    test "returns supported destination types" do
      types = Fulfillment.destination_types()

      assert :address in types
      assert :pickup_location in types
    end
  end

  describe "request_fields/0" do
    test "returns fulfillment request field definitions" do
      fields = Fulfillment.request_fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :methods end)
      assert Enum.any?(fields, fn f -> f.name == :available_methods end)
    end
  end

  describe "response_fields/0" do
    test "returns fulfillment response field definitions" do
      fields = Fulfillment.response_fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :methods end)
      assert Enum.any?(fields, fn f -> f.name == :available_methods end)
    end
  end

  describe "method_request_fields/0" do
    test "returns method request field definitions" do
      fields = Fulfillment.method_request_fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :type end)
      assert Enum.any?(fields, fn f -> f.name == :line_item_ids end)
      assert Enum.any?(fields, fn f -> f.name == :destinations end)
    end
  end

  describe "method_response_fields/0" do
    test "returns method response field definitions" do
      fields = Fulfillment.method_response_fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :id end)
      assert Enum.any?(fields, fn f -> f.name == :type end)
      assert Enum.any?(fields, fn f -> f.name == :groups end)
    end
  end

  describe "option_response_fields/0" do
    test "returns option response field definitions" do
      fields = Fulfillment.option_response_fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :id end)
      assert Enum.any?(fields, fn f -> f.name == :title end)
      assert Enum.any?(fields, fn f -> f.name == :carrier end)
      assert Enum.any?(fields, fn f -> f.name == :totals end)
    end
  end

  describe "group_response_fields/0" do
    test "returns group response field definitions" do
      fields = Fulfillment.group_response_fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :id end)
      assert Enum.any?(fields, fn f -> f.name == :options end)
      assert Enum.any?(fields, fn f -> f.name == :selected_option_id end)
    end
  end

  describe "merchant_config_fields/0" do
    test "returns merchant configuration field definitions" do
      fields = Fulfillment.merchant_config_fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :allows_multi_destination end)
      assert Enum.any?(fields, fn f -> f.name == :allows_method_combinations end)
    end
  end

  describe "default_merchant_config/0" do
    test "returns default merchant configuration" do
      config = Fulfillment.default_merchant_config()

      assert config["allows_multi_destination"] == false
      assert config["allows_method_combinations"] == false
    end
  end

  describe "default_platform_config/0" do
    test "returns default platform configuration" do
      config = Fulfillment.default_platform_config()

      assert config["supports_multi_group"] == false
    end
  end

  describe "address_fields/0" do
    test "returns address field definitions" do
      fields = Fulfillment.address_fields()

      assert is_list(fields)
      assert Enum.any?(fields, fn f -> f.name == :street end)
      assert Enum.any?(fields, fn f -> f.name == :locality end)
      assert Enum.any?(fields, fn f -> f.name == :country end)
    end
  end
end
