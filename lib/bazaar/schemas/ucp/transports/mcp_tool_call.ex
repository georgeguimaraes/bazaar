defmodule Bazaar.Schemas.Transports.McpToolCall do
  @moduledoc """
  MCP Tool Call Envelope

  UCP's MCP transport envelope for JSON-RPC tools/call messages. The schema validates the MCP mapping layer: operation name in params.name, UCP metadata and domain arguments in params.arguments, and UCP output in result.structuredContent.

  Generated from: mcp_tool_call.json
  """
  alias Bazaar.Schemas.Transports.Jsonrpc.ErrorResponse
  alias Bazaar.Schemas.Transports.McpToolCall.Request
  alias Bazaar.Schemas.Transports.McpToolCall.Response

  @variants [
    Bazaar.Schemas.Transports.McpToolCall.Request,
    Bazaar.Schemas.Transports.McpToolCall.Response,
    Bazaar.Schemas.Transports.Jsonrpc.ErrorResponse
  ]
  @doc "Returns the variant modules for this union type."
  def variants do
    @variants
  end

  @doc "Casts params to one of the variant types."
  def cast(params) when is_map(params) do
    Enum.find_value([Request, Response, ErrorResponse], {:error, :no_matching_variant}, fn mod ->
      case mod.new(params) do
        %Ecto.Changeset{valid?: true} = changeset -> {:ok, changeset}
        _ -> nil
      end
    end)
  end
end
