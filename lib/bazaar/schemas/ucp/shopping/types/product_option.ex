defmodule Bazaar.Schemas.Shopping.Types.ProductOption do
  @moduledoc """
  Product Option

  A product option such as size, color, or material.

  Generated from: product_option.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Types.OptionValue

  @field_descriptions %{
    name: "Option name (e.g., 'Size', 'Color').",
    values: "Available values for this option."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:name, :string)
    embeds_many(:values, OptionValue)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name])
    |> cast_embed(:values, required: true)
    |> validate_required([:name])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
