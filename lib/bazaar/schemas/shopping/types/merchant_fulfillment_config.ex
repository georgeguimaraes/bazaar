defmodule Bazaar.Schemas.Shopping.Types.MerchantFulfillmentConfig do
  @moduledoc """
  Merchant Fulfillment Config
  
  Merchant's fulfillment configuration.
  
  Generated from: merchant_fulfillment_config.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    allows_method_combinations: "Allowed method type combinations.",
    allows_multi_destination: "Permits multiple destinations per method type."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:allows_method_combinations, {:array, :map})
    field(:allows_multi_destination, :map)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:allows_method_combinations, :allows_multi_destination])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
