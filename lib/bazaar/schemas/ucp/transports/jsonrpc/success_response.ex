defmodule Bazaar.Schemas.Transports.Jsonrpc.SuccessResponse do
  @moduledoc """
  Schema

  JSON-RPC success response envelope.

  Generated from: jsonrpc.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @jsonrpc_values [:"2.0"]
  @field_descriptions %{
    id:
      "JSON-RPC request identifier. Notifications omit id; responses echo the request id, or use null when the request id could not be determined.",
    jsonrpc: "JSON-RPC protocol version.",
    result: "Successful transport result. UCP bindings define the nested result payload."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :map)
    field(:result, :map)
    field(:jsonrpc, Ecto.Enum, values: @jsonrpc_values)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:id, :result, :jsonrpc])
    |> validate_required([:jsonrpc, :id, :result])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
