defmodule Bazaar.Schemas.Profile.PlatformProfile do
  @moduledoc """
  UCP Platform Discovery Profile

  Full discovery profile for platforms. Exposes complete service, capability, and payment handler registries.

  Generated from: profile.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Profile.SigningKey
  alias Bazaar.Schemas.Schemas.Ucp.PlatformSchema

  @field_descriptions %{
    signing_keys:
      "Public keys for signature verification (JWK format). Used to verify signed responses, webhooks, and other authenticated messages from this party.",
    ucp: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    embeds_many(:signing_keys, SigningKey)
    embeds_one(:ucp, PlatformSchema)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [])
    |> cast_embed(:signing_keys, required: false)
    |> cast_embed(:ucp, required: true)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
