defmodule Bazaar.Schemas.Profile.SigningKey do
  @moduledoc """
  Schema

  Public key for signature verification in JWK format.

  Generated from: profile.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @use_values [:sig, :enc]
  @field_descriptions %{
    alg: "Algorithm (e.g., 'ES256', 'RS256').",
    crv: "Curve name for EC keys (e.g., 'P-256').",
    e: "Exponent for RSA public keys (base64url encoded).",
    kid: "Key ID. Referenced in signature headers to identify which key to use for verification.",
    kty: "Key type (e.g., 'EC', 'RSA').",
    n: "Modulus for RSA public keys (base64url encoded).",
    use: "Key usage. Should be 'sig' for signing keys.",
    x: "X coordinate for EC public keys (base64url encoded).",
    y: "Y coordinate for EC public keys (base64url encoded)."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:alg, :string)
    field(:crv, :string)
    field(:e, :string)
    field(:kid, :string)
    field(:kty, :string)
    field(:n, :string)
    field(:x, :string)
    field(:y, :string)
    field(:use, Ecto.Enum, values: @use_values)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:alg, :crv, :e, :kid, :kty, :n, :x, :y, :use])
    |> validate_required([:kid, :kty])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
