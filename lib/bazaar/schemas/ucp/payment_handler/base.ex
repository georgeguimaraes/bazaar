defmodule Bazaar.Schemas.PaymentHandler.Base do
  @moduledoc """
  Schema

  Shared foundation for all UCP entities.

  Generated from: payment_handler.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.AvailablePaymentInstrument
  @doc "Returns the description for a field, if available."
  def field_description(:available_instruments) do
    "Instrument types this handler supports, with optional constraints. When absent, every instrument should be considered available."
  end

  def field_description(:config) do
    "Entity-specific configuration. Structure defined by each entity's schema."
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

  def field_description(:version) do
    "Entity version in YYYY-MM-DD format."
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:config, :map)
    field(:id, :string)
    field(:schema, :string)
    field(:spec, :string)
    field(:version, :string)
    embeds_many(:available_instruments, AvailablePaymentInstrument)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:config, :id, :schema, :spec, :version])
    |> cast_embed(:available_instruments, required: false)
    |> validate_required([:version, :id])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
