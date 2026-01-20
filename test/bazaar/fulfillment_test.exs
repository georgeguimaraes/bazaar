defmodule Bazaar.FulfillmentTest do
  use ExUnit.Case, async: true

  alias Bazaar.Fulfillment

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

  describe "field accessors" do
    test "request_fields/0 returns field definitions" do
      fields = Fulfillment.request_fields()
      assert is_list(fields)
    end

    test "response_fields/0 returns field definitions" do
      fields = Fulfillment.response_fields()
      assert is_list(fields)
    end

    test "method_request_fields/0 returns field definitions" do
      fields = Fulfillment.method_request_fields()
      assert is_list(fields)
      names = Enum.map(fields, & &1.name)
      assert :type in names
    end

    test "method_response_fields/0 returns field definitions" do
      fields = Fulfillment.method_response_fields()
      assert is_list(fields)
    end

    test "address_fields/0 returns address field definitions" do
      fields = Fulfillment.address_fields()
      assert is_list(fields)
      names = Enum.map(fields, & &1.name)
      assert :street in names
      assert :country in names
    end

    test "option_response_fields/0 returns option fields" do
      fields = Fulfillment.option_response_fields()
      assert is_list(fields)
      names = Enum.map(fields, & &1.name)
      assert :id in names
      assert :title in names
    end
  end
end
