defmodule Bazaar.Schemas.Transports.A2aMessage.MessageResponse do
  @moduledoc """
  Schema

  JSON-RPC success response whose result is an A2A Message from the business agent.

  Generated from: a2a_message.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Transports.A2aMessage.Message
  @jsonrpc_values [:"2.0"]
  @field_descriptions %{
    id:
      "JSON-RPC request identifier. Notifications omit id; responses echo the request id, or use null when the request id could not be determined.",
    jsonrpc: "JSON-RPC protocol version.",
    result: "A2A Message carrying natural-language or structured UCP data parts."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :map)
    field(:jsonrpc, Ecto.Enum, values: @jsonrpc_values)
    embeds_one(:result, Message)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:id, :jsonrpc])
    |> cast_embed(:result, required: true)
    |> validate_required([:jsonrpc, :id])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
