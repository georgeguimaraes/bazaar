defmodule Bazaar.Schemas.Common.IdentityLinking.Provider do
  @moduledoc """
  Identity Provider

  A trusted identity provider for delegated authentication, keyed by the 'type' discriminator. 'oauth2' denotes an OAuth 2.0 / OIDC authorization server. Future versions MAY define additional types (e.g. wallet attestation) as non-breaking extensions; platforms MUST treat entries whose 'type' they do not support as filtered out (see Provider Selection).

  Generated from: identity_linking.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    type:
      "Provider mechanism discriminator. 'oauth2' for OAuth 2.0 / OIDC authorization servers. Additional values MAY be defined by future versions; the value is an open string, not a closed enum, so unrecognized types remain valid and are filtered at runtime."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:type, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:type]) |> validate_required([:type])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
