defmodule Bazaar.Schemas.Shopping.Types.FulfillmentDestinationReq do
  @moduledoc """
  Fulfillment Destination Request
  
  A destination for fulfillment.
  
  Generated from: fulfillment_destination_req.json
  """
  import Ecto.Changeset

  @variants [
    Bazaar.Schemas.Shopping.Types.ShippingDestinationReq,
    Bazaar.Schemas.Shopping.Types.RetailLocationReq
  ]
  @doc "Returns the variant modules for this union type."
  def variants do
    @variants
  end

  @doc "Casts params to one of the variant types."
  def cast(params) when is_map(params) do
    Enum.find_value(
      [
        Bazaar.Schemas.Shopping.Types.ShippingDestinationReq,
        Bazaar.Schemas.Shopping.Types.RetailLocationReq
      ],
      {:error, :no_matching_variant},
      fn mod ->
        case mod.new(params) do
          %Ecto.Changeset{valid?: true} = changeset -> {:ok, changeset}
          _ -> nil
        end
      end
    )
  end
end