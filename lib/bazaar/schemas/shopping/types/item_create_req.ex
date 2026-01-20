defmodule Bazaar.Schemas.Shopping.Types.ItemCreateReq do
  @moduledoc """
  Item Create Request
  
  Generated from: item.create_req.json
  """
  import Ecto.Changeset

  @fields [
    %{
      name: :id,
      type: :string,
      description:
        "Should be recognized by both the Platform, and the Business. For Google it should match the id provided in the \"id\" field in the product feed."
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:id])
  end
end