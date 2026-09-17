defmodule Bazaar.Schemas.Shopping.CatalogLookupCompleteReq.GetProductResponse do
  @moduledoc """
  Schema

  Generated from: catalog_lookup.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Policy
  alias Bazaar.Schemas.Shopping.CatalogLookupCompleteReq.DetailProduct
  alias Bazaar.Schemas.UcpCompleteReq.ResponseCatalogSchema

  @field_descriptions %{
    messages:
      "Warnings or informational messages about the product (e.g., price recently changed, limited availability).",
    policies:
      "Policies (e.g., return/refund terms) that apply to this product. `applies_to` targets are relative to the response root; when absent or empty, refer to the URLs in `links[]`.",
    product:
      "The requested product with full detail. Singular — this is a single-resource operation.",
    ucp: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:messages, {:array, :map})
    embeds_many(:policies, Policy)
    embeds_one(:product, DetailProduct)
    embeds_one(:ucp, ResponseCatalogSchema)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:messages])
    |> cast_embed(:policies, required: false)
    |> cast_embed(:product, required: true)
    |> cast_embed(:ucp, required: true)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
