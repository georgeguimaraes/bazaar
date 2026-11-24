defmodule Bazaar.Schemas.Shopping.CatalogLookupResp.GetProductResponse do
  @moduledoc """
  Schema

  Generated from: catalog_lookup_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Policy
  alias Bazaar.Schemas.Shopping.CatalogLookupResp.DetailProduct
  alias Bazaar.Schemas.UcpResp.ResponseCatalogSchema
  @doc "Returns the description for a field, if available."
  def field_description(:actions) do
    "Outstanding extension-defined Actions for this product response."
  end

  def field_description(:messages) do
    "Warnings or informational messages about the product (e.g., price recently changed, limited availability)."
  end

  def field_description(:policies) do
    "Policies (e.g., return/refund terms) that apply to this product. `applies_to` targets are relative to the response root; when absent or empty, refer to the URLs in `links[]`."
  end

  def field_description(:product) do
    "The requested product with full detail. Singular — this is a single-resource operation."
  end

  def field_description(:ucp) do
    nil
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:actions, :map)
    field(:messages, {:array, :map})
    embeds_many(:policies, Policy)
    embeds_one(:product, DetailProduct)
    embeds_one(:ucp, ResponseCatalogSchema)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:actions, :messages])
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
