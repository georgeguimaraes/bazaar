defmodule Bazaar.Schemas.Service.ResponseSchema do
  @moduledoc """
  Service (Response Schema)

  Service binding in API responses. Includes per-resource transport configuration via typed config.

  Generated from: service.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @transport_values [:rest, :mcp, :a2a, :embedded]
  @field_descriptions %{
    config: "Entity-specific configuration. Structure defined by each entity's schema.",
    endpoint: "Endpoint URL for this transport binding.",
    id:
      "Unique identifier for this entity instance. Used to disambiguate when multiple instances exist.",
    schema: "URL to JSON Schema defining this entity's structure and payloads.",
    spec: "URL to human-readable specification document.",
    transport: "Transport protocol for this service binding.",
    version: "Entity version in YYYY-MM-DD format."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:config, :map)
    field(:endpoint, :string)
    field(:id, :string)
    field(:schema, :string)
    field(:spec, :string)
    field(:version, :string)
    field(:transport, Ecto.Enum, values: @transport_values)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:config, :endpoint, :id, :schema, :spec, :version, :transport])
    |> validate_required([:version, :transport])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
