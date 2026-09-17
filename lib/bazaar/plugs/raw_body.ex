defmodule Bazaar.Plugs.RawBody do
  @moduledoc """
  A `Plug.Parsers` body reader that keeps the raw request bytes, which
  signature verification needs: a `Content-Digest` covers the body exactly
  as sent, and re-encoding the parsed JSON would not reproduce it.

      plug Plug.Parsers,
        parsers: [:json],
        json_decoder: Jason,
        body_reader: {Bazaar.Plugs.RawBody, :read_body, []}

  The bytes end up in `conn.private.bazaar_raw_body`.
  """

  @doc false
  def read_body(conn, opts) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts) do
      {:ok, body, Plug.Conn.put_private(conn, :bazaar_raw_body, body)}
    end
  end
end
