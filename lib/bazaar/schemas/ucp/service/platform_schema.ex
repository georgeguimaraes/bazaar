defmodule Bazaar.Schemas.Service.PlatformSchema do
  @moduledoc """
  Service (Platform Schema)

  Full service declaration for platform-level discovery. All transports require `version`, `spec`, and `transport`. REST, MCP, and embedded additionally require `schema`.

  Generated from: service.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @transport_values [:rest, :mcp, :a2a, :embedded]
  @doc "Returns the description for a field, if available."
  def field_description(:config) do
    "Entity-specific configuration. Structure defined by each entity's schema."
  end

  def field_description(:endpoint) do
    "Endpoint URL for this transport binding."
  end

  def field_description(:id) do
    "Unique identifier for this entity instance. Used to disambiguate when multiple instances exist."
  end

  def field_description(:schema) do
    "URL to JSON Schema defining this entity's structure and payloads."
  end

  def field_description(:spec) do
    "URL to human-readable specification document."
  end

  def field_description(:transport) do
    "Transport protocol for this service binding."
  end

  def field_description(:version) do
    "Entity version in YYYY-MM-DD format."
  end

  def field_description(field) when is_atom(field) do
    nil
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
    |> validate_required([:version, :transport, :spec])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
