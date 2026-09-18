defmodule Bazaar.Fulfillment do
  @moduledoc """
  Fulfillment capability helpers: the method and destination types UCP
  defines, and the default business and platform configuration a handler
  advertises.

  During checkout the platform sends shipping methods with its addresses,
  the business answers pickup methods with its locations, prices options
  under `fulfillment.methods[].groups[].options[]`, and the selection flows
  into the order's fulfillment expectations. `Bazaar.Checkout` implements
  those rules.
  """

  @method_types [:shipping, :pickup]
  @destination_types [:shipping_address, :business_location]

  @doc "The fulfillment method types."
  def method_types, do: @method_types

  @doc "The destination types."
  def destination_types, do: @destination_types

  @doc """
  The default business fulfillment configuration, advertised on the
  fulfillment capability: no multi-destination methods and no method
  combinations.
  """
  def default_merchant_config do
    %{
      "multi_destination" => [],
      "method_combinations" => []
    }
  end

  @doc "The default platform fulfillment configuration."
  def default_platform_config do
    %{"supports_multi_group" => false}
  end
end
