defmodule Bazaar.Schemas.Shopping.Types.FulfillmentMethodResp do
  @moduledoc """
  Fulfillment Method Response

  A fulfillment method (shipping or pickup) with destinations and groups.

  Generated from: fulfillment_method_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Types.FulfillmentGroupResp
  @type_values [:shipping, :pickup]
  @field_descriptions %{
    destinations:
      "Available destinations. For shipping: addresses. For pickup: retail locations.",
    groups:
      "Fulfillment groups for selecting options. Agent sets selected_option_id on groups to choose shipping method.",
    id: "Unique fulfillment method identifier.",
    line_item_ids: "Line item IDs fulfilled via this method.",
    selected_destination_id: "ID of the selected destination.",
    type: "Fulfillment method type."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:destinations, {:array, :map})
    field(:id, :string)
    field(:line_item_ids, {:array, :map})
    field(:selected_destination_id, :string)
    field(:type, Ecto.Enum, values: @type_values)
    embeds_many(:groups, FulfillmentGroupResp)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:destinations, :id, :line_item_ids, :selected_destination_id, :type])
    |> cast_embed(:groups, required: false)
    |> validate_required([:id, :type, :line_item_ids])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
