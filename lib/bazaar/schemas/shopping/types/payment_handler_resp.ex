defmodule Bazaar.Schemas.Shopping.Types.PaymentHandlerResp do
  @moduledoc """
  Payment Handler Response
  
  Generated from: payment_handler_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    config:
      "A dictionary containing provider-specific configuration details, such as merchant IDs, supported networks, or gateway credentials.",
    config_schema:
      "A URI pointing to a JSON Schema used to validate the structure of the config object.",
    id:
      "The unique identifier for this handler instance within the payment.handlers. Used by payment instruments to reference which handler produced them.",
    instrument_schemas: nil,
    name:
      "The specification name using reverse-DNS format. For example, dev.ucp.delegate_payment.",
    spec:
      "A URI pointing to the technical specification or schema that defines how this handler operates.",
    version: "Handler version in YYYY-MM-DD format."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:config, :map)
    field(:config_schema, :string)
    field(:id, :string)
    field(:instrument_schemas, {:array, :map})
    field(:name, :string)
    field(:spec, :string)
    field(:version, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:config, :config_schema, :id, :instrument_schemas, :name, :spec, :version])
    |> validate_required([
      :id,
      :name,
      :version,
      :spec,
      :config_schema,
      :instrument_schemas,
      :config
    ])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
