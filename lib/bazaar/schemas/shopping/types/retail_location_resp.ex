defmodule Bazaar.Schemas.Shopping.Types.RetailLocationResp do
  @moduledoc """
  Retail Location Response
  
  A pickup location (retail store, locker, etc.).
  
  Generated from: retail_location_resp.json
  """
  import Ecto.Changeset

  @fields [
    %{
      name: :address,
      type:
        Schemecto.one(Bazaar.Schemas.Shopping.Types.PostalAddress.fields(),
          with: &Function.identity/1
        ),
      description: "Physical address of the location."
    },
    %{name: :id, type: :string, description: "Unique location identifier."},
    %{name: :name, type: :string, description: "Location name (e.g., store name)."}
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:id, :name])
  end
end