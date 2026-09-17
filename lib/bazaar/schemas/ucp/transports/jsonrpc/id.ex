defmodule Bazaar.Schemas.Transports.Jsonrpc.Id do
  @moduledoc """
  Schema

  JSON-RPC request identifier. Notifications omit id; responses echo the request id, or use null when the request id could not be determined.

  Generated from: jsonrpc.json
  """
  @variants []
  @doc "Returns the variant modules for this union type."
  def variants do
    @variants
  end

  @doc "Casts params to one of the variant types."
  def cast(params) when is_map(params) do
    Enum.find_value([], {:error, :no_matching_variant}, fn mod ->
      case mod.new(params) do
        %Ecto.Changeset{valid?: true} = changeset -> {:ok, changeset}
        _ -> nil
      end
    end)
  end
end
