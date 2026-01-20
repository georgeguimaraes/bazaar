defmodule Bazaar.Schemas.Shopping.Types.MerchantFulfillmentConfig do
  @moduledoc """
  Merchant Fulfillment Config
  
  Merchant's fulfillment configuration.
  
  Generated from: merchant_fulfillment_config.json
  """
  import Ecto.Changeset

  @fields [
    %{
      name: :allows_method_combinations,
      type: {:array, :map},
      description: "Allowed method type combinations."
    },
    %{
      name: :allows_multi_destination,
      type: :map,
      description: "Permits multiple destinations per method type."
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params)
  end
end