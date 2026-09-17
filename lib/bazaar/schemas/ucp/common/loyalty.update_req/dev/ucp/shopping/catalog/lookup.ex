defmodule Bazaar.Schemas.Common.LoyaltyUpdateReq.DevUcpShoppingCatalogLookup do
  @moduledoc """
  Catalog Lookup with Loyalty Update Request

  Catalog Lookup response extended with Loyalty capability.

  Generated from: loyalty.update_req.json
  """
  alias Bazaar.Schemas.Shopping.CatalogLookupUpdateReq.GetProductResponse
  alias Bazaar.Schemas.Shopping.CatalogLookupUpdateReq.LookupResponse

  @variants [
    Bazaar.Schemas.Shopping.CatalogLookupUpdateReq.LookupResponse,
    Bazaar.Schemas.Shopping.CatalogLookupUpdateReq.GetProductResponse
  ]
  @doc "Returns the variant modules for this union type."
  def variants do
    @variants
  end

  @doc "Casts params to one of the variant types."
  def cast(params) when is_map(params) do
    Enum.find_value(
      [LookupResponse, GetProductResponse],
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
