defmodule Bazaar.Plugs.Idempotency do
  @moduledoc """
  Idempotent replay for requests carrying an `Idempotency-Key` header.

  The first response for a key is stored and replayed verbatim for a repeat of
  the same request. The same key with a different request body is a conflict
  and gets a 409. The lookup runs before the action, so replaying a completed
  checkout's completion still returns the original response.

  ## Usage

      # In your supervision tree
      children = [Bazaar.Idempotency.ETS, MyAppWeb.Endpoint]

      # In your router
      pipeline :ucp do
        plug Bazaar.Plugs.UCPHeaders
        plug Bazaar.Plugs.Idempotency
      end

  ## Options

  - `:store` - `{module, store}` implementing `Bazaar.Idempotency.Store`.
    Defaults to `{Bazaar.Idempotency.ETS, Bazaar.Idempotency.ETS}`.
  - `:methods` - request methods that take part. Defaults to
    `["POST", "PUT", "PATCH"]`.

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
      methods: Keyword.get(opts, :methods, ["POST", "PUT", "PATCH"])
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
            handle(conn, key, opts.store)
          else
            {conn, %{key: key, outcome: :skipped}}
          end

        _ ->
          {conn, %{key: nil, outcome: :skipped}}
      end
    end)
  end

  defp handle(conn, key, {store_module, store}) do
    fingerprint = :erlang.phash2({conn.method, conn.request_path, conn.body_params})

    case store_module.fetch(store, key) do
      {:ok, %{fingerprint: ^fingerprint, status: status, body: body}} ->
        replayed =
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(status, body)
          |> halt()

        {replayed, %{key: key, outcome: :replay}}

      {:ok, _other_request} ->
        conflict =
          conn
          |> send_json(
            409,
            Bazaar.Errors.response(:idempotency_conflict, protocol: protocol(conn))
          )
          |> halt()

        {conflict, %{key: key, outcome: :conflict}}

      :error ->
        stored =
          register_before_send(conn, fn conn ->
            store_module.put(store, key, %{
              fingerprint: fingerprint,
              status: conn.status,
              body: IO.iodata_to_binary(conn.resp_body)
            })

            conn
          end)

        {stored, %{key: key, outcome: :miss}}
    end
  end

  defp send_json(conn, status, document) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, JSON.encode!(document))
  end

  defp protocol(conn), do: Map.get(conn.assigns, :bazaar_protocol, :ucp)
end
