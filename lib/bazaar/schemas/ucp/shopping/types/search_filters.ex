defmodule Bazaar.Schemas.Shopping.Types.SearchFilters do
  @moduledoc """
  Search Filters

  Filter criteria to narrow search results. All specified filters combine with AND logic.

  Generated from: search_filters.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.PriceFilter

  @field_descriptions %{
    categories:
      "Filter by product categories (OR logic — matches products in any listed categories). Values match against the value field in product category entries. Valid values can be discovered from the categories field in search results, merchant documentation, or standard taxonomies that businesses may align with.",
    price: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:categories, {:array, :string})
    embeds_one(:price, PriceFilter)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:categories]) |> cast_embed(:price, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
