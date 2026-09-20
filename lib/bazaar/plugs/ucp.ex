defmodule Bazaar.Plugs.UCP do
  @moduledoc """
  The UCP request path in one plug: version negotiation, idempotent replay,
  inbound signature verification and outbound response signing.

      pipeline :ucp do
        plug :accepts, ["json"]
        plug Bazaar.Plugs.UCP
      end

      scope "/" do
        pipe_through :ucp
        bazaar_routes "/", MyApp.CommerceHandler
      end

  That is the whole wiring. The plug reads what it needs from the handler the
  route mounts and its `Bazaar.Shop`: the HTTP client for fetching a
  platform's profile, and the signing key for responses. A shop without a key
  answers unsigned; a shop without a client can't verify signatures, so signed
  requests are rejected, which is the safe direction.

  In order, each step:

    * `Bazaar.Plugs.UCPHeaders` reads `UCP-Agent` and rejects a request
      pinning a protocol version this server doesn't speak
    * `Bazaar.Plugs.Idempotency` replays a repeated `Idempotency-Key`, headers
      and all, and reserves a fresh one
    * `Bazaar.Plugs.VerifySignature` checks a signed request against the
      platform's published keys, and lets unsigned ones through
    * `Bazaar.Plugs.SignResponse` signs what the handler answers

  ## Options

  Everything the four take, passed straight through: `version:`, `store:`,
  `methods:`, `reservation_ttl:`, `required:`, `max_age:`, `cache:`,
  `http_client:`, `key:`, `statuses:`. Plus two switches:

    * `verify_signatures:` - `false` to skip verification entirely
    * `sign_responses:` - `false` to answer unsigned even with a key

  The four plugs stay public, so a pipeline that needs a different order or
  only some of them can compose its own. Response and request validation
  (`Bazaar.Plugs.ValidateResponse`, `Bazaar.Plugs.ValidateRequest`) stay
  separate: they take per-action schema configuration.
  """

  alias Bazaar.Plugs.{Idempotency, SignResponse, UCPHeaders, VerifySignature}

  @behaviour Plug

  @impl true
  def init(opts) do
    %{
      headers: UCPHeaders.init(opts),
      idempotency: Idempotency.init(opts),
      verify: Keyword.get(opts, :verify_signatures, true) && VerifySignature.init(opts),
      sign: Keyword.get(opts, :sign_responses, true) && sign_init(opts)
    }
  end

  # The key comes from the mounted shop unless the pipeline names one, and a
  # shop without a key answers unsigned, so the key is resolved per request.
  defp sign_init(opts), do: Keyword.take(opts, [:statuses, :key])

  @impl true
  def call(conn, opts) do
    conn
    |> step(opts.headers, &UCPHeaders.call/2)
    |> step(opts.idempotency, &Idempotency.call/2)
    |> step(opts.verify, &VerifySignature.call/2)
    |> sign_responses(opts.sign)
  end

  defp step(%{halted: true} = conn, _opts, _fun), do: conn
  defp step(conn, false, _fun), do: conn
  defp step(conn, opts, fun), do: fun.(conn, opts)

  defp sign_responses(%{halted: true} = conn, _opts), do: conn
  defp sign_responses(conn, false), do: conn

  defp sign_responses(conn, opts) do
    case Keyword.get(opts, :key) || shop_key(conn) do
      nil -> conn
      key -> SignResponse.call(conn, SignResponse.init(Keyword.put(opts, :key, key)))
    end
  end

  defp shop_key(conn) do
    with handler when not is_nil(handler) <- conn.assigns[:bazaar_handler],
         true <- function_exported?(handler, :__bazaar__, 1) do
      handler.__bazaar__(:shop).signing_key()
    else
      _ -> nil
    end
  end
end
