defmodule Bazaar.Schemas.Shopping.Types.RetailLocationResp do
  @moduledoc """
  Retail Location Response
  
  A pickup location (retail store, locker, etc.).
  
  Generated from: retail_location_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Types.PostalAddress

  @field_descriptions %{
    address: "Physical address of the location.",
    id: "Unique location identifier.",
    name: "Location name (e.g., store name)."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:name, :string)
    embeds_one(:address, PostalAddress)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:id, :name])
    |> cast_embed(:address, required: false)
    |> validate_required([:id, :name])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
