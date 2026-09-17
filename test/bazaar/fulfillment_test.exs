defmodule Bazaar.FulfillmentTest do
  use ExUnit.Case, async: true

  alias Bazaar.Fulfillment

  test "lists the UCP method and destination types" do
    assert Fulfillment.method_types() == [:shipping, :pickup]
    assert Fulfillment.destination_types() == [:address, :pickup_location]
  end

  test "default configurations advertise nothing beyond the basics" do
    assert Fulfillment.default_merchant_config() == %{
             "multi_destination" => [],
             "method_combinations" => []
           }

    assert Fulfillment.default_platform_config() == %{"supports_multi_group" => false}
  end
end
