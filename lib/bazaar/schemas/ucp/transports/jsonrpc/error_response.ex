defmodule Bazaar.Schemas.Transports.Jsonrpc.ErrorResponse do
  @moduledoc """
  Schema

  JSON-RPC transport error response envelope. This is for protocol-level failures, not UCP application-level messages.

  Generated from: jsonrpc.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Transports.Jsonrpc.Error
  @jsonrpc_values [:"2.0"]
  @field_descriptions %{
    error:
      "JSON-RPC transport-level error object. UCP business outcomes use result payloads with UCP messages instead of this object.",
    id:
      "JSON-RPC request identifier. Notifications omit id; responses echo the request id, or use null when the request id could not be determined.",
    jsonrpc: "JSON-RPC protocol version."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :map)
    field(:jsonrpc, Ecto.Enum, values: @jsonrpc_values)
    embeds_one(:error, Error)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:id, :jsonrpc])
    |> cast_embed(:error, required: true)
    |> validate_required([:jsonrpc, :id])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
