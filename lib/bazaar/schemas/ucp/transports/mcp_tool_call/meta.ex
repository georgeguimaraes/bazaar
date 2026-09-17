defmodule Bazaar.Schemas.Transports.McpToolCall.Meta do
  @moduledoc """
  Schema

  UCP request metadata passed through MCP params.arguments.meta.

  Generated from: mcp_tool_call.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Transports.McpToolCall.UcpAgent

  @field_descriptions %{
    "idempotency-key": "Optional idempotency key for retry-safe mutating operations.",
    "ucp-agent": "UCP-Agent metadata carried inside MCP tool arguments."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:"idempotency-key", :string)
    embeds_one(:"ucp-agent", UcpAgent)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:"idempotency-key"]) |> cast_embed(:"ucp-agent", required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
