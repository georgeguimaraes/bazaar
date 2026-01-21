defmodule Bazaar.Schemas.Capability.Response do
  @moduledoc """
  Capability (Response)
  
  Capability reference in responses. Only name/version required to confirm active capabilities.
  
  Generated from: capability.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    config: "Capability-specific configuration (structure defined by each capability).",
    extends:
      "Parent capability this extends. Present for extensions, absent for root capabilities.",
    name:
      "Stable capability identifier in reverse-domain notation (e.g., dev.ucp.shopping.checkout). Used in capability negotiation.",
    schema: "URL to JSON Schema for this capability's payload.",
    spec: "URL to human-readable specification document.",
    version: "Capability version in YYYY-MM-DD format."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:config, :map)
    field(:extends, :string)
    field(:name, :string)
    field(:schema, :string)
    field(:spec, :string)
    field(:version, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:config, :extends, :name, :schema, :spec, :version])
    |> validate_required([:name, :version])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end