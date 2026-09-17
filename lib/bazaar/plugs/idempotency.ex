defmodule Bazaar.Plugs.Idempotency do
  @moduledoc """
  Idempotent replay for requests carrying an `Idempotency-Key` header.

  The first response for a key is stored and replayed verbatim for a repeat of
  the same request. The same key with a different request body is a conflict
  and gets a 409. The key is reserved before the action runs, so a concurrent
  duplicate also gets a 409 instead of executing twice, and the lookup happens
  before the action, so replaying a completed checkout's completion still
  returns the original response.

  Only 2xx and 4xx responses are kept. A 5xx frees the key so the platform's
  retry can run the action again.

  ## Usage

      # In your supervision tree
      children = [Bazaar.Idempotency.ETS, MyAppWeb.Endpoint]

      # In your router, after Plug.Parsers has run
      pipeline :ucp do
        plug Bazaar.Plugs.UCPHeaders
        plug Bazaar.Plugs.Idempotency
      end

  `Bazaar.Idempotency.ETS` is for development and single-node deployments. In
  production, and always with more than one node, back the plug with a
  `Bazaar.Idempotency.Store` on [Cachex](https://hexdocs.pm/cachex) or your
  database, so keys expire and every node sees the same records.

  ## Options

  - `:store` - `{module, store}` implementing `Bazaar.Idempotency.Store`.
    Defaults to `{Bazaar.Idempotency.ETS, Bazaar.Idempotency.ETS}`.
  - `:methods` - request methods that take part. Defaults to
    `["POST", "PUT", "PATCH"]`.
  - `:reservation_ttl` - milliseconds after which an unfinished reservation
    (a request that crashed before responding) may be taken over. Defaults to
    30 seconds.

  The key is also available as `conn.assigns.idempotency_key` and echoed in
  the `idempotency-key` response header.
  """

  import Plug.Conn

  alias Bazaar.Telemetry

  @behaviour Plug

  @impl true
  def init(opts) do
    %{
      store: Keyword.get(opts, :store, {Bazaar.Idempotency.ETS, Bazaar.Idempotency.ETS}),
      methods: Keyword.get(opts, :methods, ["POST", "PUT", "PATCH"]),
      reservation_ttl: Keyword.get(opts, :reservation_ttl, 30_000)
    }
  end

  @impl true
  def call(conn, opts) when is_list(opts), do: call(conn, init(opts))

  def call(conn, opts) do
    Telemetry.span_with_metadata([:bazaar, :plug, :idempotency], %{}, fn ->
      case get_req_header(conn, "idempotency-key") do
        [key] when byte_size(key) > 0 ->
          conn =
            conn
            |> assign(:idempotency_key, key)
            |> put_resp_header("idempotency-key", key)

          if conn.method in opts.methods do
            handle(conn, key, opts)
          else
            {conn, %{key: key, outcome: :skipped}}
          end

        _ ->
          {conn, %{key: nil, outcome: :skipped}}
      end
    end)
  end

  defp handle(conn, key, %{store: {store_module, store}} = opts) do
    fingerprint = :erlang.phash2({conn.method, conn.request_path, conn.body_params})

    case store_module.fetch(store, key) do
      {:ok, %{fingerprint: ^fingerprint, status: status, body: body}} ->
        {conn |> send_json(status, body) |> halt(), %{key: key, outcome: :replay}}

      {:ok, %{fingerprint: ^fingerprint, reserved_at: reserved_at}} ->
        if stale?(reserved_at, opts.reservation_ttl) do
          store_module.release(store, key)
          reserve(conn, key, fingerprint, opts)
        else
          {reject(conn, :idempotency_in_progress), %{key: key, outcome: :in_progress}}
        end

      {:ok, _other_request} ->
        {reject(conn, :idempotency_conflict), %{key: key, outcome: :conflict}}

      :error ->
        reserve(conn, key, fingerprint, opts)
    end
  end

  # Claims the key before the action runs. Losing the race means another
  # request with this key is in flight or was just recorded.
  defp reserve(conn, key, fingerprint, %{store: {store_module, store}}) do
    reservation = %{fingerprint: fingerprint, reserved_at: System.system_time(:millisecond)}

    case store_module.reserve(store, key, reservation) do
      :ok ->
        conn =
          register_before_send(conn, fn conn ->
            if conn.status in 200..499 do
              store_module.put(store, key, %{
                fingerprint: fingerprint,
                status: conn.status,
                body: IO.iodata_to_binary(conn.resp_body)
              })
            else
              store_module.release(store, key)
            end

            conn
          end)

        {conn, %{key: key, outcome: :miss}}

      {:error, :taken} ->
        {reject(conn, :idempotency_in_progress), %{key: key, outcome: :in_progress}}
    end
  end

  defp stale?(reserved_at, ttl), do: System.system_time(:millisecond) - reserved_at > ttl

  defp reject(conn, reason) do
    protocol = Map.get(conn.assigns, :bazaar_protocol, :ucp)
    document = Bazaar.Errors.response(reason, protocol: protocol)

    conn |> send_json(409, JSON.encode!(document)) |> halt()
  end

  defp send_json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, body)
  end
end
