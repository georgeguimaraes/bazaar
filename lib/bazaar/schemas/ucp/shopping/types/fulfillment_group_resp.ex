defmodule Bazaar.Schemas.Shopping.Types.FulfillmentGroupResp do
  @moduledoc """
  Fulfillment Group Response

  A merchant-generated package/group of line items with fulfillment options.

  Generated from: fulfillment_group_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Types.FulfillmentOptionResp
  @doc "Returns the description for a field, if available."
  def field_description(:id) do
    "Group identifier for referencing merchant-generated groups in updates."
  end

  def field_description(:line_item_ids) do
    "Line item IDs included in this group/package."
  end

  def field_description(:options) do
    "Available fulfillment options for this group."
  end

  def field_description(:selected_option_id) do
    "ID of the selected fulfillment option for this group."
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:line_item_ids, {:array, :string})
    field(:selected_option_id, :string)
    embeds_many(:options, FulfillmentOptionResp)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:id, :line_item_ids, :selected_option_id])
    |> cast_embed(:options, required: false)
    |> validate_required([:id, :line_item_ids])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
