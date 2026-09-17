defmodule Bazaar.Schemas.Shopping.Types.Category do
  @moduledoc """
  Category

  A product category with optional taxonomy identifier.

  Generated from: category.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    taxonomy:
      "Source taxonomy. Well-known values: `google_product_category`, `shopify`, `merchant`.",
    value: "Category value or path (e.g., 'Apparel > Shirts', '1604')."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:taxonomy, :string)
    field(:value, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:taxonomy, :value]) |> validate_required([:value])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
