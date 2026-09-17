defmodule Bazaar.Schemas.Common.LoyaltyCompleteReq.DevUcpShoppingCatalogLookup do
  @moduledoc """
  Catalog Lookup with Loyalty Complete Request

  Catalog Lookup response extended with Loyalty capability.

  Generated from: loyalty.complete_req.json
  """
  alias Bazaar.Schemas.Shopping.CatalogLookupCompleteReq.GetProductResponse
  alias Bazaar.Schemas.Shopping.CatalogLookupCompleteReq.LookupResponse

  @variants [
    Bazaar.Schemas.Shopping.CatalogLookupCompleteReq.LookupResponse,
    Bazaar.Schemas.Shopping.CatalogLookupCompleteReq.GetProductResponse
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
