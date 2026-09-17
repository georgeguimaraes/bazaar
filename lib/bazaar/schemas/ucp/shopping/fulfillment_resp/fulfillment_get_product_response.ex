defmodule Bazaar.Schemas.Shopping.FulfillmentResp.FulfillmentGetProductResponse do
  @moduledoc """
  Schema

  Generated from: fulfillment_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Policy
  alias Bazaar.Schemas.Shopping.FulfillmentResp.FulfillmentDetailProduct
  alias Bazaar.Schemas.UcpResp.ResponseCatalogSchema

  @field_descriptions %{
    actions: "Outstanding extension-defined Actions for this product response.",
    messages:
      "Warnings or informational messages about the product (e.g., price recently changed, limited availability).",
    policies:
      "Policies (e.g., return/refund terms) that apply to this product. `applies_to` targets are relative to the response root; when absent or empty, refer to the URLs in `links[]`.",
    product:
      "A get_product detail product (carrying selected/options availability signals) whose variants are fulfillment-enriched. Used by get_product.",
    ucp: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:actions, :map)
    field(:messages, {:array, :map})
    embeds_many(:policies, Policy)
    embeds_one(:product, FulfillmentDetailProduct)
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
