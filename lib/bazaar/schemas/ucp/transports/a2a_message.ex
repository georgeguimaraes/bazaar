defmodule Bazaar.Schemas.Transports.A2aMessage do
  @moduledoc """
  A2A UCP Message Envelope

  Minimal A2A envelope shapes used by UCP's A2A checkout binding. This schema validates UCP's transport mapping points — Agent Card extension advertisement, inbound A2A Message requests, and JSON-RPC responses carrying A2A Message results — without attempting to re-specify the full A2A protocol.

  Generated from: a2a_message.json
  """
  alias Bazaar.Schemas.Transports.A2aMessage.AgentCard
  alias Bazaar.Schemas.Transports.A2aMessage.MessageRequest
  alias Bazaar.Schemas.Transports.A2aMessage.MessageResponse

  @variants [
    Bazaar.Schemas.Transports.A2aMessage.AgentCard,
    Bazaar.Schemas.Transports.A2aMessage.MessageRequest,
    Bazaar.Schemas.Transports.A2aMessage.MessageResponse
  ]
  @doc "Returns the variant modules for this union type."
  def variants do
    @variants
  end

  @doc "Casts params to one of the variant types."
  def cast(params) when is_map(params) do
    Enum.find_value(
      [AgentCard, MessageRequest, MessageResponse],
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
