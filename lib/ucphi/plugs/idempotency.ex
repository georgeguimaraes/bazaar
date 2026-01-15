defmodule Ucphi.Plugs.Idempotency do
  @moduledoc """
  Plug that handles idempotency keys for UCP requests.

  Idempotency ensures that retried requests don't create duplicate
  resources. When a request includes an `Idempotency-Key` header,
  the response is cached and returned for subsequent requests with
  the same key.

  ## Usage

      pipeline :ucp do
        plug Ucphi.Plugs.Idempotency
      end

  ## Options

  - `:cache` - Cache module to use (default: `Ucphi.Plugs.Idempotency.ETSCache`)
  - `:ttl` - Time-to-live for cached responses in seconds (default: 86400 / 24 hours)
  - `:header` - Name of the idempotency header (default: "idempotency-key")

  ## Headers

  Requests should include:
  - `Idempotency-Key`: Unique key for this request

  Responses include:
  - `Idempotency-Key`: Echo of the request key
  - `Idempotency-Replay`: "true" if this is a cached response
  """

  import Plug.Conn

  @behaviour Plug

  @default_opts [
    cache: Ucphi.Plugs.Idempotency.ETSCache,
    ttl: 86_400,
    header: "idempotency-key"
  ]

  @impl true
  def init(opts) do
    Keyword.merge(@default_opts, opts)
  end

  @impl true
  def call(conn, opts) do
    header_name = Keyword.fetch!(opts, :header)

    case get_req_header(conn, header_name) do
      [key] when byte_size(key) > 0 ->
        handle_idempotent_request(conn, key, opts)

      _ ->
        # No idempotency key, pass through
        conn
    end
  end

  defp handle_idempotent_request(conn, key, opts) do
    cache = Keyword.fetch!(opts, :cache)
    ttl = Keyword.fetch!(opts, :ttl)
    header_name = Keyword.fetch!(opts, :header)

    cache_key = build_cache_key(conn, key)

    case cache.get(cache_key) do
      {:ok, cached_response} ->
        # Return cached response
        conn
        |> put_resp_header(header_name, key)
        |> put_resp_header("idempotency-replay", "true")
        |> send_cached_response(cached_response)
        |> halt()

      :miss ->
        # Register callback to cache the response
        conn
        |> put_resp_header(header_name, key)
        |> assign(:ucphi_idempotency_key, cache_key)
        |> assign(:ucphi_idempotency_cache, cache)
        |> assign(:ucphi_idempotency_ttl, ttl)
        |> register_before_send(&cache_response/1)
    end
  end

  defp build_cache_key(conn, key) do
    # Include method and path to ensure keys are scoped
    "#{conn.method}:#{conn.request_path}:#{key}"
  end

  defp cache_response(conn) do
    case conn.assigns do
      %{ucphi_idempotency_key: key, ucphi_idempotency_cache: cache, ucphi_idempotency_ttl: ttl} ->
        if conn.status in 200..299 do
          response = %{
            status: conn.status,
            headers: conn.resp_headers,
            body: conn.resp_body
          }

          cache.put(key, response, ttl)
        end

        conn

      _ ->
        conn
    end
  end

  defp send_cached_response(conn, %{status: status, body: body}) do
    conn
    |> put_status(status)
    |> send_resp(status, body)
  end

  # Default ETS-based cache implementation
  defmodule ETSCache do
    @moduledoc """
    Simple ETS-based cache for idempotency responses.

    For production, consider using Redis or another distributed cache.
    """

    @table :ucphi_idempotency_cache

    def init do
      if :ets.whereis(@table) == :undefined do
        :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
      end

      :ok
    end

    def get(key) do
      init()

      case :ets.lookup(@table, key) do
        [{^key, response, expires_at}] ->
          if System.system_time(:second) < expires_at do
            {:ok, response}
          else
            :ets.delete(@table, key)
            :miss
          end

        [] ->
          :miss
      end
    end

    def put(key, response, ttl) do
      init()
      expires_at = System.system_time(:second) + ttl
      :ets.insert(@table, {key, response, expires_at})
      :ok
    end

    def delete(key) do
      init()
      :ets.delete(@table, key)
      :ok
    end
  end
end
