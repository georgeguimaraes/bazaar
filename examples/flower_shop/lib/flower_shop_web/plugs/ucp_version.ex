defmodule FlowerShopWeb.Plugs.UcpVersion do
  @moduledoc """
  Version negotiation. A platform may pin the protocol version it speaks with
  `UCP-Agent: profile="..."; version="YYYY-MM-DD"`. This shop serves exactly
  one version, so any other one is rejected with 422.
  """

  import Plug.Conn

  alias FlowerShop.Webhooks
  alias FlowerShopWeb.Responses

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    supported = Bazaar.DiscoveryProfile.version()

    case Webhooks.requested_version(conn.assigns[:ucp_agent]) do
      nil ->
        conn

      ^supported ->
        conn

      requested ->
        conn
        |> Responses.error(
          422,
          "unsupported_version",
          "UCP version #{requested} is not supported, this server speaks #{supported}"
        )
        |> halt()
    end
  end
end
