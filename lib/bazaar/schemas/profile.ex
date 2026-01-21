defmodule Bazaar.Schemas.Profile do
  @moduledoc """
  UCP Discovery Profile
  
  Full UCP discovery profile for /.well-known/ucp endpoint
  
  Generated from: profile.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    payment: "Payment configuration",
    signing_keys: "JWK public keys for signature verification",
    ucp: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:payment, :map)
    field(:signing_keys, {:array, :map})
    field(:ucp, :map)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:payment, :signing_keys, :ucp]) |> validate_required([:ucp])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
