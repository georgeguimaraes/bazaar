defmodule Bazaar.Schemas.Shopping.Types.FulfillmentMethodResp do
  @moduledoc """
  Fulfillment Method Response

  A fulfillment method with destinations and groups.

  Generated from: fulfillment_method_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Types.FulfillmentDestinationResp
  alias Bazaar.Schemas.Shopping.Types.FulfillmentGroupResp

  @field_descriptions %{
    destinations:
      "Available destinations for this method. In Business responses, each destination carries a `type` and `id`.",
    groups:
      "Fulfillment groups for selecting options. Agent sets selected_option_id on groups to choose shipping method.",
    id: "Unique fulfillment method identifier.",
    line_item_ids: "Line item IDs fulfilled via this method.",
    selected_destination_id:
      "ID of the selected destination. Accepts any stable, Business-scoped ID the Business recognizes for this method, including Location IDs not yet enumerated in `destinations`.",
    type:
      "Fulfillment method type. Well-known values: `shipping`, `pickup`. Businesses MAY use additional values."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:line_item_ids, {:array, :string})
    field(:selected_destination_id, :string)
    field(:type, :string)
    embeds_many(:destinations, FulfillmentDestinationResp)
    embeds_many(:groups, FulfillmentGroupResp)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:id, :line_item_ids, :selected_destination_id, :type])
    |> cast_embed(:destinations, required: false)
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
