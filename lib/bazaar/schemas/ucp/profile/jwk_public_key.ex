defmodule Bazaar.Schemas.Profile.JwkPublicKey do
  @moduledoc """
  Ed25519 pairs with EdDSA

  Public JSON Web Key used for HTTP Message Signatures and signed webhook verification. UCP profiles publish public keys only; private key material MUST NOT appear in a profile. Well-known key types: EC (ECDSA P-256, P-384) and OKP (EdDSA Ed25519); OKP keys are RECOMMENDED for signers opting into Web Bot Auth (WBA) interop on HTTP transport. A single profile MAY publish keys of either or both types; consumers select keys by kid. The kty, crv, and alg vocabularies are OPEN: verifiers MUST tolerate key types, curves, and algorithms they do not recognize, selecting keys by kid at verification time. An unsupported key affects only the signature that references it (algorithm_unsupported) and MUST NOT cause whole-profile rejection. Additional public JWK members are permitted; consumers ignore unknown members.

  Generated from: profile.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    alg:
      "JWA algorithm associated with this public key. Optional; verifiers derive the algorithm from crv when alg is omitted. When present for a well-known curve it MUST match: ES256 with P-256, ES384 with P-384, EdDSA with Ed25519.",
    crv: "Curve name. Well-known values: P-256, P-384 (EC); Ed25519 (OKP). Open vocabulary.",
    kid:
      "Key identifier referenced by Signature-Input keyid. For keys used in dual-audience (Web Bot Auth) signatures, the kid MUST be the key's JWK SHA-256 Thumbprint (RFC 7638) so UCP-Agent and Signature-Agent lookups resolve the same key; otherwise the kid MAY be any stable string.",
    kty:
      "JWK key type. Well-known values: EC for ECDSA (P-256, P-384); OKP for EdDSA (Ed25519). Open vocabulary; verifiers tolerate unrecognized types and select keys by kid.",
    use: "JWK public key use. UCP examples use sig for signatures.",
    x:
      "Public key value, base64url-encoded. For EC, the x coordinate (RFC 7518 §6.2); for OKP, the public key (RFC 8037 §2).",
    y: "EC public key y coordinate, base64url-encoded (RFC 7518 §6.2). Not used by OKP keys."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:alg, :string)
    field(:crv, :string)
    field(:kid, :string)
    field(:kty, :string)
    field(:use, :string)
    field(:x, :string)
    field(:y, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:alg, :crv, :kid, :kty, :use, :x, :y])
    |> validate_required([:kid, :kty])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
