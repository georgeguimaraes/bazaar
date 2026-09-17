defmodule Bazaar.Fulfillment do
  @moduledoc """
  Fulfillment capability helpers: the method and destination types UCP
  defines, and the default business and platform configuration a handler
  advertises.

  The request and response shapes themselves come from the generated
  `Bazaar.Schemas.Shopping.Fulfillment*` modules. During checkout the platform
  sends methods with destinations, the business answers with options and
  pricing under `fulfillment.methods[].groups[].options[]`, and the selected
  option flows into the order's fulfillment expectations (see
  `Bazaar.Order.from_checkout/3`).
  """

  @method_types [:shipping, :pickup]
  @destination_types [:address, :pickup_location]

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
