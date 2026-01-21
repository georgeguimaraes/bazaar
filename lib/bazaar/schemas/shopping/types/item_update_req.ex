defmodule Bazaar.Schemas.Shopping.Types.ItemUpdateReq do
  @moduledoc """
  Item Update Request
  
  Generated from: item.update_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    id:
      "Should be recognized by both the Platform, and the Business. For Google it should match the id provided in the \"id\" field in the product feed."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:id]) |> validate_required([:id])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end