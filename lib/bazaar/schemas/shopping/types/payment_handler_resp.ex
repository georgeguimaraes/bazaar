defmodule Bazaar.Schemas.Shopping.Types.PaymentHandlerResp do
  @moduledoc """
  Payment Handler Response
  
  Generated from: payment_handler_resp.json
  """
  import Ecto.Changeset

  @fields [
    %{
      name: :config,
      type: :map,
      description:
        "A dictionary containing provider-specific configuration details, such as merchant IDs, supported networks, or gateway credentials."
    },
    %{
      name: :config_schema,
      type: :string,
      description:
        "A URI pointing to a JSON Schema used to validate the structure of the config object."
    },
    %{
      name: :id,
      type: :string,
      description:
        "The unique identifier for this handler instance within the payment.handlers. Used by payment instruments to reference which handler produced them."
    },
    %{name: :instrument_schemas, type: {:array, :string}},
    %{
      name: :name,
      type: :string,
      description:
        "The specification name using reverse-DNS format. For example, dev.ucp.delegate_payment."
    },
    %{
      name: :spec,
      type: :string,
      description:
        "A URI pointing to the technical specification or schema that defines how this handler operates."
    },
    %{name: :version, type: :string, description: "Handler version in YYYY-MM-DD format."}
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params)
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
end