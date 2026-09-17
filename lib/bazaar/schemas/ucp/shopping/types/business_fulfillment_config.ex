defmodule Bazaar.Schemas.Shopping.Types.BusinessFulfillmentConfig do
  @moduledoc """
  Business Fulfillment Config

  Business's fulfillment configuration.

  Generated from: business_fulfillment_config.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    method_combinations:
      "Method-type combinations the business permits within one cart. Each inner array is a permitted set of method `type` values (e.g. shipping + pickup).",
    multi_destination:
      "Method types that permit multiple destinations within one cart (e.g. split shipping across addresses). Listing a method permits it; an omitted method does not. Open — businesses MAY list any method type."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:method_combinations, {:array, :map})
    field(:multi_destination, {:array, :map})
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:method_combinations, :multi_destination])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
