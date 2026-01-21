defmodule Bazaar.Schemas.Shopping.Types.FulfillmentGroupUpdateReq do
  @moduledoc """
  Fulfillment Group Update Request
  
  A merchant-generated package/group of line items with fulfillment options.
  
  Generated from: fulfillment_group.update_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    id: "Group identifier for referencing merchant-generated groups in updates.",
    selected_option_id: "ID of the selected fulfillment option for this group."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:selected_option_id, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:id, :selected_option_id]) |> validate_required([:id])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
