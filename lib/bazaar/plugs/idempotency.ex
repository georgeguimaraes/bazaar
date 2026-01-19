defmodule Bazaar.Plugs.Idempotency do
  @moduledoc """
  Plug that extracts idempotency keys from UCP requests.

  When a request includes an `Idempotency-Key` header, the key is stored
  in `conn.assigns.idempotency_key` for use in handlers.

  ## Usage

      pipeline :ucp do
        plug Bazaar.Plugs.Idempotency
      end

  ## Note

  This plug only extracts the header. For production idempotency with
  response caching, implement your own caching layer (Redis, database, etc.)
  using the extracted key.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case get_req_header(conn, "idempotency-key") do
      [key] when byte_size(key) > 0 ->
        conn
        |> assign(:idempotency_key, key)
        |> put_resp_header("idempotency-key", key)

      _ ->
        conn
    end
  end
end
