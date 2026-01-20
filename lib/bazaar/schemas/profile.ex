defmodule Bazaar.Schemas.Profile do
  @moduledoc """
  UCP Discovery Profile
  
  Full UCP discovery profile for /.well-known/ucp endpoint
  
  Generated from: profile.json
  """
  import Ecto.Changeset

  @fields [
    %{name: :payment, type: :map, description: "Payment configuration"},
    %{
      name: :signing_keys,
      type: {:array, :map},
      description: "JWK public keys for signature verification"
    },
    %{name: :ucp, type: :map}
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:ucp])
  end
end