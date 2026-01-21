defmodule Bazaar.Schemas.Shopping.Types.ItemResp do
  @moduledoc """
  Item Response
  
  Generated from: item_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    id:
      "Should be recognized by both the Platform, and the Business. For Google it should match the id provided in the \"id\" field in the product feed.",
    image_url: "Product image URI.",
    price: "Unit price in minor (cents) currency units.",
    title: "Product title."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:image_url, :string)
    field(:price, :integer)
    field(:title, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:id, :image_url, :price, :title])
    |> validate_required([:id, :title, :price])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end