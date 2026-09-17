defmodule Bazaar.Schemas.Common.Types.PriceFilter do
  @moduledoc """
  Price Filter

  Price range filter denominated in context.currency. When context.currency matches the presentment currency, businesses apply the filter directly. When it differs, businesses SHOULD convert filter values to the presentment currency before applying; if conversion is not supported, businesses MAY ignore the filter and SHOULD indicate this via a message. When context.currency is absent, filter denomination is ambiguous and businesses MAY ignore it.

  Generated from: price_filter.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    max: "Maximum price in ISO 4217 minor units.",
    min: "Minimum price in ISO 4217 minor units."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:max, :integer)
    field(:min, :integer)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:max, :min])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
