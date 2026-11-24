defmodule Bazaar.Schemas.Shopping.Types.FulfillmentAvailableMethodResp do
  @moduledoc """
  Fulfillment Available Method Response

  Inventory availability hint for a fulfillment method type.

  Generated from: fulfillment_available_method_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @doc "Returns the description for a field, if available."
  def field_description(:description) do
    "Human-readable availability info (e.g., 'Available for pickup at Downtown Store today')."
  end

  def field_description(:fulfillable_on) do
    "'now' for immediate availability, or ISO 8601 date for future (preorders, transfers)."
  end

  def field_description(:line_item_ids) do
    "Line items available for this fulfillment method."
  end

  def field_description(:type) do
    "Fulfillment method type this availability applies to. Well-known values: `shipping`, `pickup`; businesses MAY use additional values."
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:description, :string)
    field(:fulfillable_on, :string)
    field(:line_item_ids, {:array, :string})
    field(:type, :string)
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
