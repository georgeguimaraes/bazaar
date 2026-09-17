defmodule Bazaar.Schemas.Profile.Base do
  @moduledoc """
  Schema

  Common wrapper for UCP profile documents.

  Generated from: profile.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Profile.JwkPublicKey
  alias Bazaar.Schemas.UcpResp.Base

  @field_descriptions %{
    keys:
      "Canonical UCP profile field for publishing signing keys, as a JWK Set per RFC 7517. When a profile publishes signing keys, they MUST appear here; this is where every UCP verifier reads them. Publishing keys[] makes the UCP profile a valid JWK Set that a signer can reuse as its Web Bot Auth key source: a WBA-shape verifier resolving via Signature-Agent type=jwks_uri pointed at this profile reads these keys, and the cimd and directory variants reach them through their own documents. See the Deployment Patterns for WBA Interop section in the overview for hosting patterns.",
    ucp:
      "Protocol metadata, capabilities, services, and payment handlers advertised by this party."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    embeds_many(:keys, JwkPublicKey)
    embeds_one(:ucp, Base)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [])
    |> cast_embed(:keys, required: false)
    |> cast_embed(:ucp, required: true)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
