defmodule Bazaar.Schemas.Shopping.Types.ItemResp do
  @moduledoc """
  Item Response
  
  Generated from: item_resp.json
  """
  import Ecto.Changeset

  @fields [
    %{
      name: :id,
      type: :string,
      description:
        "Should be recognized by both the Platform, and the Business. For Google it should match the id provided in the \"id\" field in the product feed."
    },
    %{name: :image_url, type: :string, description: "Product image URI."},
    %{name: :price, type: :integer, description: "Unit price in minor (cents) currency units."},
    %{name: :title, type: :string, description: "Product title."}
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:id, :title, :price])
  end
end