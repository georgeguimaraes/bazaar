defmodule Bazaar.Schemas.Shopping.CatalogSearchResp.SearchResponse do
  @moduledoc """
  Schema

  Generated from: catalog_search_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Pagination.Response
  alias Bazaar.Schemas.Common.Types.Policy
  alias Bazaar.Schemas.Shopping.Types.Product
  alias Bazaar.Schemas.UcpResp.ResponseCatalogSchema

  @field_descriptions %{
    actions: "Outstanding extension-defined Actions for this catalog search response.",
    messages: "Errors, warnings, or informational messages about the search results.",
    pagination: nil,
    policies:
      "Policies (e.g., return/refund terms) that apply to the products in these search results. `applies_to` targets are relative to the response root; when absent or empty, refer to the URLs in `links[]`.",
    products: "Products matching the search criteria.",
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
    embeds_one(:pagination, Response)
    embeds_many(:policies, Policy)
    embeds_many(:products, Product)
    embeds_one(:ucp, ResponseCatalogSchema)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:actions, :messages])
    |> cast_embed(:pagination, required: false)
    |> cast_embed(:policies, required: false)
    |> cast_embed(:products, required: true)
    |> cast_embed(:ucp, required: true)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
