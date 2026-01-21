defmodule Bazaar.Protocol.TransformerTest do
  use ExUnit.Case, async: true

  alias Bazaar.Protocol.Transformer

  describe "transform_request/2 with :acp protocol" do
    test "transforms ACP address fields to UCP format" do
      acp_request = %{
        "buyer" => %{
          "name" => "John Doe",
          "email" => "john@example.com",
          "shipping_address" => %{
            "name" => "John Doe",
            "line_one" => "123 Main St",
            "line_two" => "Apt 4",
            "city" => "San Francisco",
            "state" => "CA",
            "country" => "US",
            "postal_code" => "94102"
          }
        }
      }

      {:ok, result} = Transformer.transform_request(acp_request, :acp)

      assert result["buyer"]["shipping_address"]["street_address"] == "123 Main St"
      assert result["buyer"]["shipping_address"]["extended_address"] == "Apt 4"
      assert result["buyer"]["shipping_address"]["address_locality"] == "San Francisco"
      assert result["buyer"]["shipping_address"]["address_region"] == "CA"
      assert result["buyer"]["shipping_address"]["address_country"] == "US"
      assert result["buyer"]["shipping_address"]["postal_code"] == "94102"
      refute Map.has_key?(result["buyer"]["shipping_address"], "line_one")
      refute Map.has_key?(result["buyer"]["shipping_address"], "line_two")
      refute Map.has_key?(result["buyer"]["shipping_address"], "city")
      refute Map.has_key?(result["buyer"]["shipping_address"], "state")
      refute Map.has_key?(result["buyer"]["shipping_address"], "country")
    end

    test "transforms ACP line_items to UCP items format" do
      acp_request = %{
        "line_items" => [
          %{
            "product" => %{
              "name" => "Test Product",
              "id" => "SKU-001"
            },
            "quantity" => 2,
            "base_amount" => 1000
          }
        ]
      }

      {:ok, result} = Transformer.transform_request(acp_request, :acp)

      assert [item] = result["items"]
      assert item["name"] == "Test Product"
      assert item["sku"] == "SKU-001"
      assert item["quantity"] == 2
      assert item["price"] == 1000
    end

    test "preserves other fields unchanged" do
      acp_request = %{
        "currency" => "USD",
        "custom_field" => "custom_value"
      }

      {:ok, result} = Transformer.transform_request(acp_request, :acp)

      assert result["currency"] == "USD"
      assert result["custom_field"] == "custom_value"
    end

    test "returns request unchanged for :ucp protocol" do
      ucp_request = %{
        "items" => [%{"sku" => "TEST", "quantity" => 1}]
      }

      {:ok, result} = Transformer.transform_request(ucp_request, :ucp)

      assert result == ucp_request
    end
  end

  describe "transform_response/2 with :acp protocol" do
    test "transforms UCP status to ACP status" do
      ucp_response = %{
        "id" => "checkout_123",
        "status" => "incomplete"
      }

      {:ok, result} = Transformer.transform_response(ucp_response, :acp)

      assert result["status"] == "not_ready_for_payment"
    end

    test "transforms all UCP statuses correctly" do
      status_mappings = [
        {"incomplete", "not_ready_for_payment"},
        {"requires_escalation", "authentication_required"},
        {"ready_for_complete", "ready_for_payment"},
        {"complete_in_progress", "in_progress"},
        {"completed", "completed"},
        {"canceled", "canceled"}
      ]

      for {ucp_status, expected_acp_status} <- status_mappings do
        ucp_response = %{"id" => "test", "status" => ucp_status}
        {:ok, result} = Transformer.transform_response(ucp_response, :acp)

        assert result["status"] == expected_acp_status,
               "Expected #{ucp_status} -> #{expected_acp_status}"
      end
    end

    test "transforms UCP address fields to ACP format" do
      ucp_response = %{
        "buyer" => %{
          "shipping_address" => %{
            "name" => "John Doe",
            "street_address" => "123 Main St",
            "extended_address" => "Apt 4",
            "address_locality" => "San Francisco",
            "address_region" => "CA",
            "address_country" => "US",
            "postal_code" => "94102"
          }
        }
      }

      {:ok, result} = Transformer.transform_response(ucp_response, :acp)

      address = result["buyer"]["shipping_address"]
      assert address["line_one"] == "123 Main St"
      assert address["line_two"] == "Apt 4"
      assert address["city"] == "San Francisco"
      assert address["state"] == "CA"
      assert address["country"] == "US"
      assert address["postal_code"] == "94102"
    end

    test "transforms UCP items to ACP line_items format" do
      ucp_response = %{
        "items" => [
          %{
            "name" => "Test Product",
            "sku" => "SKU-001",
            "quantity" => 2,
            "price" => 1000
          }
        ]
      }

      {:ok, result} = Transformer.transform_response(ucp_response, :acp)

      assert [line_item] = result["line_items"]
      assert line_item["product"]["name"] == "Test Product"
      assert line_item["product"]["id"] == "SKU-001"
      assert line_item["quantity"] == 2
      assert line_item["base_amount"] == 1000
    end

    test "returns response unchanged for :ucp protocol" do
      ucp_response = %{
        "id" => "checkout_123",
        "status" => "incomplete"
      }

      {:ok, result} = Transformer.transform_response(ucp_response, :ucp)

      assert result == ucp_response
    end
  end

  describe "transform_address/2" do
    test "transforms ACP to UCP address" do
      acp_address = %{
        "name" => "John",
        "line_one" => "123 Main",
        "line_two" => "Suite 1",
        "city" => "NYC",
        "state" => "NY",
        "country" => "US",
        "postal_code" => "10001"
      }

      result = Transformer.transform_address(acp_address, :acp_to_ucp)

      assert result["street_address"] == "123 Main"
      assert result["extended_address"] == "Suite 1"
      assert result["address_locality"] == "NYC"
      assert result["address_region"] == "NY"
      assert result["address_country"] == "US"
      assert result["name"] == "John"
      assert result["postal_code"] == "10001"
    end

    test "transforms UCP to ACP address" do
      ucp_address = %{
        "name" => "John",
        "street_address" => "123 Main",
        "extended_address" => "Suite 1",
        "address_locality" => "NYC",
        "address_region" => "NY",
        "address_country" => "US",
        "postal_code" => "10001"
      }

      result = Transformer.transform_address(ucp_address, :ucp_to_acp)

      assert result["line_one"] == "123 Main"
      assert result["line_two"] == "Suite 1"
      assert result["city"] == "NYC"
      assert result["state"] == "NY"
      assert result["country"] == "US"
      assert result["name"] == "John"
      assert result["postal_code"] == "10001"
    end

    test "handles nil input" do
      assert Transformer.transform_address(nil, :acp_to_ucp) == nil
      assert Transformer.transform_address(nil, :ucp_to_acp) == nil
    end
  end

  describe "edge cases" do
    test "handles empty maps" do
      {:ok, result} = Transformer.transform_request(%{}, :acp)
      assert result == %{}

      {:ok, result} = Transformer.transform_response(%{}, :acp)
      assert result == %{}
    end

    test "handles missing optional fields" do
      acp_request = %{
        "buyer" => %{
          "email" => "test@example.com"
        }
      }

      {:ok, result} = Transformer.transform_request(acp_request, :acp)
      assert result["buyer"]["email"] == "test@example.com"
    end

    test "handles nested fulfillment addresses" do
      ucp_response = %{
        "fulfillment" => %{
          "destination" => %{
            "street_address" => "456 Oak Ave",
            "address_locality" => "Boston",
            "address_region" => "MA",
            "address_country" => "US",
            "postal_code" => "02101"
          }
        }
      }

      {:ok, result} = Transformer.transform_response(ucp_response, :acp)

      dest = result["fulfillment"]["destination"]
      assert dest["line_one"] == "456 Oak Ave"
      assert dest["city"] == "Boston"
      assert dest["state"] == "MA"
      assert dest["country"] == "US"
    end
  end
end
