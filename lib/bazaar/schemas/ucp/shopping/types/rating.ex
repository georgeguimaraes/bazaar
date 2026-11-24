defmodule Bazaar.Schemas.Shopping.Types.Rating do
  @moduledoc """
  Rating

  Product rating aggregate.

  Generated from: rating.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @doc "Returns the description for a field, if available."
  def field_description(:count) do
    "Number of reviews contributing to the rating."
  end

  def field_description(:scale_max) do
    "Maximum value on the rating scale (e.g., 5 for 5-star)."
  end

  def field_description(:scale_min) do
    "Minimum value on the rating scale (e.g., 1 for 1-5 stars)."
  end

  def field_description(:value) do
    "Average rating value."
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:count, :integer)
    field(:scale_max, :float)
    field(:scale_min, :float)
    field(:value, :float)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:count, :scale_max, :scale_min, :value])
    |> validate_required([:value, :scale_max])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
