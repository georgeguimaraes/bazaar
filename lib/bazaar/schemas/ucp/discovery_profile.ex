defmodule Bazaar.Schemas.Ucp.DiscoveryProfile do
  @moduledoc """
  UCP Discovery Profile

  Full UCP metadata for /.well-known/ucp discovery.

  Generated from: ucp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Capability.Discovery

  @field_descriptions %{
    capabilities: "Supported capabilities and extensions.",
    services: "Service definitions keyed by reverse-domain service name.",
    version: "UCP protocol version in YYYY-MM-DD format."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:services, :map)
    field(:version, :string)
    embeds_many(:capabilities, Discovery)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:services, :version])
    |> cast_embed(:capabilities, required: true)
    |> validate_required([:version, :services])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
