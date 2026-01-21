defmodule Bazaar.Schemas.Shopping.Types.Buyer do
  @moduledoc """
  Buyer
  
  Generated from: buyer.json
  """
  @fields [
    %{name: :email, type: :string, description: "Email of the buyer."},
    %{name: :first_name, type: :string, description: "First name of the buyer."},
    %{
      name: :full_name,
      type: :string,
      description:
        "Optional, buyer's full name (if first_name or last_name fields are present they take precedence)."
    },
    %{name: :last_name, type: :string, description: "Last name of the buyer."},
    %{name: :phone_number, type: :string, description: "E.164 standard."}
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params)
  end
end