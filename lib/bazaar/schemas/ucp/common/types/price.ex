defmodule Bazaar.Schemas.Common.Types.Price do
  @moduledoc """
  Price

  Price with explicit currency.

  Generated from: price.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    amount: "Amount in ISO 4217 minor units. Use 0 for free items.",
    currency: "ISO 4217 currency code (e.g., 'USD', 'EUR', 'GBP')."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:amount, :integer)
    field(:currency, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:amount, :currency]) |> validate_required([:amount, :currency])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
