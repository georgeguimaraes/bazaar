defmodule Bazaar.Schemas.Common.Types.PriceRange do
  @moduledoc """
  Price Range

  A price range representing minimum and maximum values (e.g., a common example in retail shopping is when prices vary across product variants).

  Generated from: price_range.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Price
  @field_descriptions %{max: "Maximum price in the range.", min: "Minimum price in the range."}
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    embeds_one(:max, Price)
    embeds_one(:min, Price)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [])
    |> cast_embed(:max, required: true)
    |> cast_embed(:min, required: true)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
