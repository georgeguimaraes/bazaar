defmodule Bazaar.Plugs.SignResponse do
  @moduledoc """
  Signs successful responses with RFC 9421 HTTP message signatures, the way
  the spec recommends for checkout completion and payment responses and
  allows everywhere else: `@status`, `Content-Digest` and `Content-Type` are
  covered, `keyid` names the key, and platforms verify against the public
  half published as `"keys"` in your business profile.

      plug Bazaar.Plugs.SignResponse, key: &MyApp.Signing.key/0

  ## Options

  - `:key` - a `Bazaar.Signing.Key` or a zero-arity function returning one
    (for keys loaded at boot), required
  - `:statuses` - the statuses to sign (default: `200..299`)

  Emits `[:bazaar, :plug, :sign_response]` spans with the signed status.
  """

  import Plug.Conn

  alias Bazaar.Signing.HttpSignature
  alias Bazaar.Telemetry

  @behaviour Plug

  @impl Plug
  def init(opts) do
    %{key: Keyword.fetch!(opts, :key), statuses: Keyword.get(opts, :statuses, 200..299)}
  end

  @impl Plug
  def call(conn, opts) do
    register_before_send(conn, fn conn ->
      if conn.status in opts.statuses, do: sign(conn, opts), else: conn
    end)
  end

  defp sign(conn, opts) do
    Telemetry.span_with_metadata([:bazaar, :plug, :sign_response], %{status: conn.status}, fn ->
      key = if is_function(opts.key, 0), do: opts.key.(), else: opts.key
      body = IO.iodata_to_binary(conn.resp_body || "")

      response = %{
        status: conn.status,
        headers: Enum.filter(conn.resp_headers, fn {name, _} -> name == "content-type" end),
        body: body
      }

      signed =
        response
        |> HttpSignature.sign_response(key)
        |> Enum.reject(fn {name, _} -> name == "content-type" end)

      conn =
        Enum.reduce(signed, conn, fn {name, value}, conn -> put_resp_header(conn, name, value) end)

      {conn, %{keyid: key.kid}}
    end)
  end
end
