defmodule Bazaar.Schemas.Shopping.Types.FulfillmentAvailableMethodResp do
  @moduledoc """
  Fulfillment Available Method Response
  
  Inventory availability hint for a fulfillment method type.
  
  Generated from: fulfillment_available_method_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @type_values [:shipping, :pickup]
  @field_descriptions %{
    description:
      "Human-readable availability info (e.g., 'Available for pickup at Downtown Store today').",
    fulfillable_on:
      "'now' for immediate availability, or ISO 8601 date for future (preorders, transfers).",
    line_item_ids: "Line items available for this fulfillment method.",
    type: "Fulfillment method type this availability applies to."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:description, :string)
    field(:fulfillable_on, :string)
    field(:line_item_ids, {:array, :map})
    field(:type, Ecto.Enum, values: @type_values)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:description, :fulfillable_on, :line_item_ids, :type])
    |> validate_required([:type, :line_item_ids])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
