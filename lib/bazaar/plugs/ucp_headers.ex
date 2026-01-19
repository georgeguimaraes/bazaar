defmodule Bazaar.Plugs.UCPHeaders do
  @moduledoc """
  Plug that extracts and validates UCP-specific headers.

  ## Usage

      pipeline :ucp do
        plug Bazaar.Plugs.UCPHeaders
      end

  ## Headers Processed

  - `UCP-Agent`: Platform/agent identifier URI
  - `UCP-Request-ID`: Unique request identifier for tracing
  - `Request-Signature`: Request signature for verification

  Values are stored in `conn.assigns` for use in handlers:

  - `conn.assigns.ucp_agent` - Agent identifier
  - `conn.assigns.ucp_request_id` - Request ID
  - `conn.assigns.ucp_signature` - Request signature
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    conn
    |> extract_header("ucp-agent", :ucp_agent)
    |> extract_header("ucp-request-id", :ucp_request_id)
    |> extract_header("request-signature", :ucp_signature)
    |> maybe_generate_request_id()
  end

  defp extract_header(conn, header_name, assign_key) do
    case get_req_header(conn, header_name) do
      [value] when byte_size(value) > 0 ->
        assign(conn, assign_key, value)

      _ ->
        conn
    end
  end

  defp maybe_generate_request_id(conn) do
    case conn.assigns[:ucp_request_id] do
      nil ->
        request_id = generate_request_id()

        conn
        |> assign(:ucp_request_id, request_id)
        |> put_resp_header("ucp-request-id", request_id)

      request_id ->
        put_resp_header(conn, "ucp-request-id", request_id)
    end
  end

  defp generate_request_id do
    "req_" <> Base.encode32(:crypto.strong_rand_bytes(12), case: :lower, padding: false)
  end
end
