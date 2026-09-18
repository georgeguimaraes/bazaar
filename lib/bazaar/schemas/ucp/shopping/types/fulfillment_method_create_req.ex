defmodule Bazaar.Schemas.Shopping.Types.FulfillmentMethodCreateReq do
  @moduledoc """
  Fulfillment Method Create Request

  A fulfillment method with destinations and groups.

  Generated from: fulfillment_method.create_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Types.FulfillmentGroupCreateReq

  @field_descriptions %{
    groups:
      "Fulfillment groups for selecting options. Agent sets selected_option_id on groups to choose shipping method.",
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
    field(:selected_destination_id, :string)
    field(:type, :string)
    embeds_many(:groups, FulfillmentGroupCreateReq)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:selected_destination_id, :type])
    |> cast_embed(:groups, required: false)
    |> validate_required([:type])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
