defmodule Bazaar.Schemas.Shopping.FulfillmentUpdateReq.FulfillmentSearchFilters do
  @moduledoc """
  Search Filters

  Catalog filters extended with a fulfillment destination filter and a method-type filter.

  Generated from: fulfillment.update_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.PriceFilter
  alias Bazaar.Schemas.Shopping.Types.FulfillmentDestinationFilter

  @field_descriptions %{
    categories:
      "Filter by product categories (OR logic — matches products in any listed categories). Values match against the value field in product category entries. Valid values can be discovered from the categories field in search results, merchant documentation, or standard taxonomies that businesses may align with.",
    fulfills_to:
      "Explicit destination where items are fulfilled. It may differ from the locality or Business Location supplied in `context` (e.g. a gift delivered directly to the recipient). The filter restricts results to what can be fulfilled there and seeds method `availability`. It supersedes `context` only for fulfillment destination and availability resolution.",
    methods:
      "Restrict results to these fulfillment method types (e.g. [\"pickup\"]). Well-known values: `shipping`, `pickup`.",
    price: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:categories, {:array, :string})
    field(:methods, {:array, :string})
    embeds_one(:fulfills_to, FulfillmentDestinationFilter)
    embeds_one(:price, PriceFilter)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:categories, :methods])
    |> cast_embed(:fulfills_to, required: false)
    |> cast_embed(:price, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
