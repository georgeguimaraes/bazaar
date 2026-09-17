defmodule Bazaar.Plugs.UCPHeaders do
  @moduledoc """
  Reads the UCP request headers and negotiates the protocol version.

  ## Usage

      pipeline :ucp do
        plug Bazaar.Plugs.UCPHeaders
      end

  ## Headers

  - `UCP-Agent`: the platform identifies itself with
    `profile="https://platform.example/.well-known/ucp"` and may pin the
    protocol version it speaks with `; version="YYYY-MM-DD"`
  - `UCP-Request-ID`: request identifier for tracing, generated when absent
  - `Request-Signature`: request signature, passed through for verification

  Values land in `conn.assigns`: `ucp_agent` (raw header), `ucp_agent_profile`,
  `ucp_agent_version`, `ucp_request_id` and `ucp_signature`.

  ## Options

  - `:version` - the protocol version this server speaks. A request pinning a
    different version is rejected with 422. Defaults to
    `Bazaar.DiscoveryProfile.version()`; `false` disables negotiation.
  """

  import Plug.Conn

  alias Bazaar.Telemetry

  @behaviour Plug

  @impl true
  def init(opts), do: %{version: Keyword.get(opts, :version, Bazaar.DiscoveryProfile.version())}

  @impl true
  def call(conn, opts) when is_list(opts), do: call(conn, init(opts))

  def call(conn, opts) do
    Telemetry.span_with_metadata([:bazaar, :plug, :ucp_headers], %{}, fn ->
      result =
        conn
        |> extract_header("ucp-agent", :ucp_agent)
        |> extract_header("ucp-request-id", :ucp_request_id)
        |> extract_header("request-signature", :ucp_signature)
        |> maybe_generate_request_id()
        |> assign_agent()
        |> negotiate_version(opts.version)

      {result, %{request_id: result.assigns[:ucp_request_id]}}
    end)
  end

  @doc """
  Parses a `UCP-Agent` header value into its `profile` and `version` parameters.

      iex> Bazaar.Plugs.UCPHeaders.parse_agent(~s(profile="https://p.example/.well-known/ucp"; version="2026-08-25"))
      %{profile: "https://p.example/.well-known/ucp", version: "2026-08-25"}
  """
  def parse_agent(header) when is_binary(header) do
    %{profile: parameter(header, "profile"), version: parameter(header, "version")}
  end

  def parse_agent(_), do: %{profile: nil, version: nil}

  defp parameter(header, name) do
    case Regex.run(~r/#{name}="([^"]*)"/, header) do
      [_, value] when value != "" -> value
      _ -> nil
    end
  end

  defp extract_header(conn, header_name, assign_key) do
    case get_req_header(conn, header_name) do
      [value] when byte_size(value) > 0 -> assign(conn, assign_key, value)
      _ -> conn
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

  defp assign_agent(conn) do
    %{profile: profile, version: version} = parse_agent(conn.assigns[:ucp_agent])

    conn
    |> assign(:ucp_agent_profile, profile)
    |> assign(:ucp_agent_version, version)
  end

  defp negotiate_version(conn, false), do: conn

  defp negotiate_version(conn, supported) do
    case conn.assigns.ucp_agent_version do
      nil ->
        conn

      ^supported ->
        conn

      requested ->
        protocol = Map.get(conn.assigns, :bazaar_protocol, :ucp)

        document =
          Bazaar.Errors.response({:unsupported_version, requested, supported}, protocol: protocol)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(422, JSON.encode!(document))
        |> halt()
    end
  end

  defp generate_request_id do
    "req_" <> Base.encode32(:crypto.strong_rand_bytes(12), case: :lower, padding: false)
  end
end
