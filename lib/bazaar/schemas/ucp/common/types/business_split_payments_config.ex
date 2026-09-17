defmodule Bazaar.Schemas.Common.Types.BusinessSplitPaymentsConfig do
  @moduledoc """
  Business Split Payments Config

  Business-level configuration for split payments. Declaring the capability means multiple payment instruments are supported; this config declares which combinations are valid.

  Generated from: business_split_payments_config.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    allowed_combinations:
      "Array of valid instrument combinations. Each combination is an array of instrument groups. A payment is valid if it matches any combination."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:allowed_combinations, {:array, :map})
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:allowed_combinations]) |> validate_required([:allowed_combinations])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
