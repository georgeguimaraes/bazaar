defmodule Bazaar.Schemas.Ucp.DiscoveryProfile do
  @moduledoc """
  UCP Discovery Profile
  
  Full UCP metadata for /.well-known/ucp discovery.
  
  Generated from: ucp.json
  """
  import Ecto.Changeset

  @fields [
    %{
      name: :capabilities,
      type:
        Schemecto.many(Bazaar.Schemas.Capability.Discovery.fields(), with: &Function.identity/1),
      description: "Supported capabilities and extensions."
    },
    %{
      name: :services,
      type: :map,
      description: "Service definitions keyed by reverse-domain service name."
    },
    %{name: :version, type: :string, description: "UCP protocol version in YYYY-MM-DD format."}
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:version, :services, :capabilities])
  end
end