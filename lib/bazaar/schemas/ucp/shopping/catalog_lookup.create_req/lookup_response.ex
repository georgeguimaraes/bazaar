defmodule Bazaar.Schemas.Shopping.CatalogLookupCreateReq.LookupResponse do
  @moduledoc """
  Schema

  Generated from: catalog_lookup.create_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Policy
  alias Bazaar.Schemas.Shopping.Types.Product
  alias Bazaar.Schemas.UcpCreateReq.ResponseCatalogSchema
  @doc "Returns the description for a field, if available."
  def field_description(:messages) do
    "Errors, warnings, or informational messages about the requested items."
  end

  def field_description(:policies) do
    "Policies (e.g., return/refund terms) that apply to the products in this response. `applies_to` targets are relative to the response root; when absent or empty, refer to the URLs in `links[]`."
  end

  def field_description(:products) do
    "Products matching the requested identifiers. May contain fewer items if some identifiers not found, or more if identifiers match multiple products."
  end

  def field_description(:ucp) do
    nil
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:messages, {:array, :map})
    embeds_many(:policies, Policy)
    embeds_many(:products, Product)
    embeds_one(:ucp, ResponseCatalogSchema)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:messages])
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
