defmodule FlowerShopWeb.Plugs.Idempotency do
  @moduledoc """
  Idempotent replay for requests carrying an `Idempotency-Key` header.

  The first response for a key is stored and replayed verbatim for the same
  request. The same key with a different body is a conflict (409). The lookup
  happens before the action runs, so a replayed completion still returns the
  original response even though the checkout has moved on.
  """

  import Plug.Conn

  alias FlowerShop.Store
  alias FlowerShopWeb.Responses

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{method: method} = conn, _opts) when method in ["POST", "PUT"] do
    case get_req_header(conn, "idempotency-key") do
      [key] when byte_size(key) > 0 -> handle(conn, key, fingerprint(conn))
      _ -> conn
    end
  end

  def call(conn, _opts), do: conn

  defp handle(conn, key, fingerprint) do
    case Store.get_idempotency(key) do
      %{fingerprint: ^fingerprint, status: status, body: body} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(status, body)
        |> halt()

      %{} ->
        conn
        |> Responses.error(
          409,
          "idempotency_conflict",
          "Idempotency-Key #{key} was already used with a different request"
        )
        |> halt()

      nil ->
        register_before_send(conn, fn conn ->
          Store.put_idempotency(key, %{
            fingerprint: fingerprint,
            status: conn.status,
            body: IO.iodata_to_binary(conn.resp_body)
          })

          conn
        end)
    end
  end

  defp fingerprint(conn), do: :erlang.phash2({conn.method, conn.request_path, conn.body_params})
end
