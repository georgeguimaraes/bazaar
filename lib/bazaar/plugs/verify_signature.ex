defmodule Bazaar.Plugs.VerifySignature do
  @moduledoc """
  Verifies RFC 9421 signatures on requests from platforms.

  A platform that signs its requests names its profile in `UCP-Agent` and
  publishes its public keys there as a JWK set. This plug fetches that
  profile, picks the key the signature's `keyid` names, and verifies the
  signature and the body digest. It runs after `Bazaar.Plugs.UCPHeaders`
  (for the profile URL) and after `Plug.Parsers` with
  `Bazaar.Plugs.RawBody` as its body reader (for the raw body).

  Unsigned requests pass unless `required: true`: the spec leaves inbound
  verification to the business, and the conformance suite sends none.

      plug Plug.Parsers, parsers: [:json], json_decoder: Jason,
        body_reader: {Bazaar.Plugs.RawBody, :read_body, []}

      pipeline :ucp do
        plug :accepts, ["json"]
        plug Bazaar.Plugs.UCP
        plug Bazaar.Plugs.VerifySignature, cache: MyApp.ProfileCache.map()
      end

  ## Options

  - `:http_client` - a 1-arity GET; without one the handler's shop supplies
    `http_client/0`'s `get`, so a mounted store needs nothing here
  - `:cache` - optional `Bazaar.Platform.discover_cached/3` cache map, so a
    platform's keys are fetched once
  - `:required` - reject unsigned requests with 401 (default `false`)
  - `:max_age` - seconds a signature's `created` may lie in the past (default 300)

  A verified request gets `conn.assigns.ucp_signature` with the `keyid` and
  `created` of the signature. Failures answer 401 with an error document:
  `invalid_signature`, `signer_unknown` (profile unreachable or no usable
  key) or `signature_required`.
  """

  import Plug.Conn

  alias Bazaar.Platform
  alias Bazaar.Signing.{HttpSignature, Key}

  @behaviour Plug

  @impl true
  def init(opts) do
    %{
      http_client: Keyword.get(opts, :http_client),
      cache: Keyword.get(opts, :cache),
      required: Keyword.get(opts, :required, false),
      max_age: Keyword.get(opts, :max_age, 300)
    }
  end

  @impl true
  def call(conn, opts) do
    Bazaar.Telemetry.span_with_metadata([:bazaar, :plug, :verify_signature], %{}, fn ->
      case get_req_header(conn, "signature-input") do
        [] when opts.required -> {reject(conn, :signature_required), %{outcome: :rejected}}
        [] -> {conn, %{outcome: :unsigned}}
        _ -> verify(conn, opts)
      end
    end)
  end

  defp verify(conn, opts) do
    request = request(conn)

    with {:ok, keys} <- platform_keys(conn.assigns[:ucp_agent_profile], conn, opts),
         {:ok, params} <- verify_with_any(request, candidates(keys, request)),
         :ok <- fresh(params, opts.max_age) do
      {assign(conn, :ucp_signature, %{keyid: params.keyid, created: params.created}),
       %{outcome: :verified, keyid: params.keyid}}
    else
      {:error, :signer_unknown} -> {reject(conn, :signer_unknown), %{outcome: :rejected}}
      {:error, _reason} -> {reject(conn, :invalid_signature), %{outcome: :rejected}}
    end
  end

  # The key the signature names, or every published key when it names none.
  defp candidates(keys, request) do
    keyid = HttpSignature.keyid(request.headers)

    named = Enum.filter(keys, &(&1["kid"] == keyid))

    if(named == [], do: keys, else: named)
    |> Enum.flat_map(fn jwk ->
      try do
        [Key.from_jwk(jwk)]
      rescue
        ArgumentError -> []
      end
    end)
  end

  defp verify_with_any(_request, []), do: {:error, :signer_unknown}

  defp verify_with_any(request, keys) do
    Enum.find_value(keys, {:error, :invalid_signature}, fn key ->
      case HttpSignature.verify(request, key) do
        {:ok, params} -> {:ok, params}
        _ -> nil
      end
    end)
  end

  # The signed @authority is the request target's, i.e. the Host header, and the
  # scheme is what the client used, which a TLS-terminating proxy reports in
  # X-Forwarded-Proto.
  defp request(conn) do
    query = if conn.query_string == "", do: "", else: "?" <> conn.query_string
    host = List.first(get_req_header(conn, "host")) || "#{conn.host}:#{conn.port}"
    scheme = List.first(get_req_header(conn, "x-forwarded-proto")) || to_string(conn.scheme)

    %{
      method: conn.method,
      url: "#{scheme}://#{host}#{conn.request_path}#{query}",
      headers: conn.req_headers,
      body: raw_body(conn)
    }
  end

  defp raw_body(conn) do
    case conn.private[:bazaar_raw_body] do
      nil when conn.method in ["GET", "HEAD", "DELETE"] ->
        ""

      nil ->
        raise "Bazaar.Plugs.VerifySignature needs the raw body; configure Plug.Parsers with body_reader: {Bazaar.Plugs.RawBody, :read_body, []}"

      body ->
        body
    end
  end

  defp platform_keys(nil, _conn, _opts), do: {:error, :signer_unknown}

  defp platform_keys(profile_url, conn, opts) do
    result =
      with {:ok, get} <- http_client(conn, opts) do
        case opts.cache do
          nil -> Platform.discover(profile_url, http_client: get)
          cache -> Platform.discover_cached(profile_url, cache, http_client: get)
        end
      end

    case result do
      {:ok, profile} ->
        case profile["keys"] || get_in(profile, ["ucp", "keys"]) do
          [_ | _] = keys -> {:ok, keys}
          _ -> {:error, :signer_unknown}
        end

      {:error, _} ->
        {:error, :signer_unknown}
    end
  end

  # The client given to the plug, else the shop's, through the mounted handler.
  defp http_client(_conn, %{http_client: get}) when is_function(get, 1), do: {:ok, get}

  defp http_client(conn, _opts) do
    with handler when not is_nil(handler) <- conn.assigns[:bazaar_handler],
         true <- function_exported?(handler, :__bazaar__, 1),
         %{get: get} when is_function(get, 1) <- handler.__bazaar__(:shop).http_client() do
      {:ok, get}
    else
      _ -> {:error, :signer_unknown}
    end
  end

  defp fresh(params, max_age) do
    now = System.os_time(:second)

    cond do
      params.created && now - params.created > max_age -> {:error, :stale}
      params.expires && params.expires < now -> {:error, :expired}
      true -> :ok
    end
  end

  defp reject(conn, reason) do
    protocol = Map.get(conn.assigns, :bazaar_protocol, :ucp)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, JSON.encode!(Bazaar.Errors.response(reason, protocol: protocol)))
    |> halt()
  end
end
