defmodule Bazaar.Schemas.Transports.Jsonrpc do
  @moduledoc """
  JSON-RPC 2.0 Envelope

  Common JSON-RPC 2.0 transport envelope used by UCP JSON-RPC-based bindings. This schema intentionally validates only the protocol envelope; binding-specific params and result payloads are validated by transport-specific schemas or extracted UCP payload schemas.

  Generated from: jsonrpc.json
  """
  alias Bazaar.Schemas.Transports.Jsonrpc.ErrorResponse
  alias Bazaar.Schemas.Transports.Jsonrpc.Request
  alias Bazaar.Schemas.Transports.Jsonrpc.SuccessResponse

  @variants [
    Bazaar.Schemas.Transports.Jsonrpc.Request,
    Bazaar.Schemas.Transports.Jsonrpc.SuccessResponse,
    Bazaar.Schemas.Transports.Jsonrpc.ErrorResponse
  ]
  @doc "Returns the variant modules for this union type."
  def variants do
    @variants
  end

  @doc "Casts params to one of the variant types."
  def cast(params) when is_map(params) do
    Enum.find_value(
      [Request, SuccessResponse, ErrorResponse],
      {:error, :no_matching_variant},
      fn mod ->
        case mod.new(params) do
          %Ecto.Changeset{valid?: true} = changeset -> {:ok, changeset}
          _ -> nil
        end
      end
    )
  end
end
