defmodule Bazaar.Schemas.Shopping.Types.PlatformFulfillmentConfig do
  @moduledoc """
  Platform Fulfillment Config
  
  Platform's fulfillment configuration.
  
  Generated from: platform_fulfillment_config.json
  """
  @fields [
    %{
      name: :supports_multi_group,
      type: :boolean,
      description: "Enables multiple groups per method."
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