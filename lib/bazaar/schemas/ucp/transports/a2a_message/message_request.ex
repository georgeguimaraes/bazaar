defmodule Bazaar.Schemas.Transports.A2aMessage.MessageRequest do
  @moduledoc """
  Schema

  A2A message/send JSON-RPC request whose params carry a UCP-bearing Message from the platform to the business agent.

  Generated from: a2a_message.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @jsonrpc_values [:"2.0"]
  @method_values [:"message/send"]
  @field_descriptions %{
    id:
      "JSON-RPC request identifier. Notifications omit id; responses echo the request id, or use null when the request id could not be determined.",
    jsonrpc: "JSON-RPC protocol version.",
    method: "Transport method name. Binding-specific schemas constrain the method namespace.",
    params: "Method parameters. Binding-specific schemas define the object shape."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :map)
    field(:params, :map)
    field(:jsonrpc, Ecto.Enum, values: @jsonrpc_values)
    field(:method, Ecto.Enum, values: @method_values)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:id, :params, :jsonrpc, :method])
    |> validate_required([:jsonrpc, :method, :params])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
