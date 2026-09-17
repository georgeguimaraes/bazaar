defmodule Bazaar.Schemas.Common.LoyaltyCreateReq.DevUcpShoppingCatalogLookup do
  @moduledoc """
  Catalog Lookup with Loyalty Create Request

  Catalog Lookup response extended with Loyalty capability.

  Generated from: loyalty.create_req.json
  """
  alias Bazaar.Schemas.Shopping.CatalogLookupCreateReq.GetProductResponse
  alias Bazaar.Schemas.Shopping.CatalogLookupCreateReq.LookupResponse

  @variants [
    Bazaar.Schemas.Shopping.CatalogLookupCreateReq.LookupResponse,
    Bazaar.Schemas.Shopping.CatalogLookupCreateReq.GetProductResponse
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
