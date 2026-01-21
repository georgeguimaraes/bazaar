defmodule Bazaar.Schemas.Capability.Base do
  @moduledoc """
  Schema
  
  Generated from: capability.json
  """
  @fields [
    %{
      name: :config,
      type: :map,
      description: "Capability-specific configuration (structure defined by each capability)."
    },
    %{
      name: :extends,
      type: :string,
      description:
        "Parent capability this extends. Present for extensions, absent for root capabilities."
    },
    %{
      name: :name,
      type: :string,
      description:
        "Stable capability identifier in reverse-domain notation (e.g., dev.ucp.shopping.checkout). Used in capability negotiation."
    },
    %{
      name: :schema,
      type: :string,
      description: "URL to JSON Schema for this capability's payload."
    },
    %{name: :spec, type: :string, description: "URL to human-readable specification document."},
    %{name: :version, type: :string, description: "Capability version in YYYY-MM-DD format."}
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params)
  end
end