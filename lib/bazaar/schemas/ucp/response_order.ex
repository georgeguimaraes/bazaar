defmodule Bazaar.Schemas.Ucp.ResponseOrder do
  @moduledoc """
  UCP Order Response
  
  UCP metadata for order responses. No payment handlers needed post-purchase.
  
  Generated from: ucp.json
  """
  import Ecto.Changeset

  @fields [
    %{
      name: :capabilities,
      type:
        Schemecto.many(Bazaar.Schemas.Capability.Response.fields(), with: &Function.identity/1),
      description: "Active capabilities for this response."
    },
    %{name: :version, type: :string, description: "UCP protocol version in YYYY-MM-DD format."}
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:version, :capabilities])
  end
end