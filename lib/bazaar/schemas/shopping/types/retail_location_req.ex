defmodule Bazaar.Schemas.Shopping.Types.RetailLocationReq do
  @moduledoc """
  Retail Location Request
  
  A pickup location (retail store, locker, etc.).
  
  Generated from: retail_location_req.json
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
    %{name: :name, type: :string, description: "Location name (e.g., store name)."}
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:name])
  end
end