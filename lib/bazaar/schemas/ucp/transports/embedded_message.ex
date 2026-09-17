defmodule Bazaar.Schemas.Transports.EmbeddedMessage do
  @moduledoc """
  Embedded Protocol Message Envelope

  JSON-RPC envelope for UCP Embedded Protocol (EP) messages exchanged between a host and an embedded context. This schema constrains the shared transport envelope and method namespace while leaving capability-specific params and result payloads to their capability schemas.

  Generated from: embedded_message.json
  """
  alias Bazaar.Schemas.Transports.EmbeddedMessage.Request
  alias Bazaar.Schemas.Transports.EmbeddedMessage.Response
  alias Bazaar.Schemas.Transports.Jsonrpc.ErrorResponse

  @variants [
    Bazaar.Schemas.Transports.EmbeddedMessage.Request,
    Bazaar.Schemas.Transports.EmbeddedMessage.Response,
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
