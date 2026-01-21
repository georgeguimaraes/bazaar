defmodule Bazaar.Schemas.Shopping.Types.FulfillmentGroupCreateReq do
  @moduledoc """
  Fulfillment Group Create Request

  A merchant-generated package/group of line items with fulfillment options.

  Generated from: fulfillment_group.create_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    selected_option_id: "ID of the selected fulfillment option for this group."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:selected_option_id, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:selected_option_id])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
