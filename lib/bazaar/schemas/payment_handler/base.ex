defmodule Bazaar.Schemas.PaymentHandler.Base do
  @moduledoc """
  Schema

  Shared foundation for all UCP entities.

  Generated from: payment_handler.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    config: "Entity-specific configuration. Structure defined by each entity's schema.",
    id:
      "Unique identifier for this entity instance. Used to disambiguate when multiple instances exist.",
    schema: "URL to JSON Schema defining this entity's structure and payloads.",
    spec: "URL to human-readable specification document.",
    version: "Entity version in YYYY-MM-DD format."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:config, :map)
    field(:id, :string)
    field(:schema, :string)
    field(:spec, :string)
    field(:version, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:config, :id, :schema, :spec, :version])
    |> validate_required([:version, :id])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
