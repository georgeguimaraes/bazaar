# Plugs Guide

Bazaar provides plugs for UCP implementations:

| Plug | Purpose |
|------|---------|
| `UCP` | `UCPHeaders` followed by `Idempotency`, one plug for the whole pipeline |
| `UCPHeaders` | Read the UCP headers and negotiate the protocol version |
| `Idempotency` | Replay responses for repeated `Idempotency-Key` requests |
| `VerifySignature` | Verify RFC 9421 signatures on requests from platforms |
| `ValidateRequest` | Validate request bodies against the generated schemas |
| `SignResponse` | Sign successful responses with RFC 9421 signatures platforms verify against your published key |
| `ValidateResponse` | Validate response bodies against the spec's JSON Schemas (needs `jsv`) |

## Setting Up Plugs

Add the plugs to your router pipeline, and the idempotency store to your supervision tree:

```elixir
# lib/my_app/application.ex
children = [
  Bazaar.Idempotency.ETS,
  MyAppWeb.Endpoint
]

# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Bazaar.Phoenix.Router

  pipeline :ucp do
    plug :accepts, ["json"]
    plug Bazaar.Plugs.UCP
  end

  scope "/" do
    pipe_through :ucp
    bazaar_routes "/", MyApp.UCPHandler
  end
end
```

`Bazaar.Plugs.UCP` runs `UCPHeaders` and then `Idempotency`, and hands its options to both (`store:`, `methods:`, `reservation_ttl:`, `version:`). The sections below describe each plug; use them directly when something has to run between the two.

## UCPHeaders

Reads the UCP request headers and negotiates the protocol version.

### What It Does

1. Reads `UCP-Agent` and parses its `profile` and `version` parameters
2. Reads `UCP-Request-ID`, or generates one, and echoes it in the response
3. Reads `Request-Signature` for verification downstream
4. Rejects requests pinning a protocol version this server doesn't speak with a 422 error document

### Usage

```elixir
plug Bazaar.Plugs.UCPHeaders
plug Bazaar.Plugs.UCPHeaders, version: false   # skip version negotiation
```

The negotiated version defaults to `Bazaar.DiscoveryProfile.version()`, the spec version the library implements.

### Accessing Headers in Handler

```elixir
def create_checkout(params, conn) do
  conn.assigns[:ucp_agent]          # raw header, e.g. ~s(profile="https://platform.example/.well-known/ucp")
  conn.assigns[:ucp_agent_profile]  # "https://platform.example/.well-known/ucp"
  conn.assigns[:ucp_agent_version]  # "2026-08-25" or nil
  conn.assigns[:ucp_request_id]     # "req_abc123..."
  conn.assigns[:ucp_signature]
  # ...
end
```

The profile URL is where the platform advertises its capabilities, including the webhook URL for order events.

## Idempotency

Replays responses for repeated requests that carry an `Idempotency-Key` header.

### What It Does

1. On the first request for a key, stores the response status and body once the action has run
2. On a repeat with the same key and the same method, path and body, replays the stored response verbatim and halts
3. On a repeat with the same key but a different body, answers 409 with an error document
4. Only `POST`, `PUT` and `PATCH` take part; other methods just get the key in `conn.assigns.idempotency_key`

The lookup runs before the action, so replaying a completed checkout's completion still returns the original response. The key is reserved before the action runs, so a second identical request arriving while the first is still in flight gets a 409 instead of running twice. The plug fingerprints `conn.body_params`, so it must run after `Plug.Parsers` (any Phoenix endpoint does this).

### Usage

```elixir
plug Bazaar.Plugs.Idempotency
plug Bazaar.Plugs.Idempotency, store: {MyApp.RedisIdempotency, :orders}, methods: ["POST"]
```

### Stores

`Bazaar.Idempotency.ETS` keeps records in memory, never expires them, and only knows about its own node. Use it for development and a single-node deployment. In production, and always with more than one node, back the plug with [Cachex](https://hexdocs.pm/cachex): its entries carry a TTL, so keys expire instead of growing forever, and its routers spread the cache across a cluster, so a retry that lands on another node still finds the record.

`Bazaar.Idempotency.Cachex` is that store. Add `{:cachex, "~> 4.1"}` to your deps, start a cache with a default expiration, and point the plug at it:

```elixir
# application.ex
import Cachex.Spec
children = [
  {Cachex, [:idempotency, [expiration: expiration(default: :timer.hours(24))]]},
  MyAppWeb.Endpoint
]

# router.ex
plug Bazaar.Plugs.UCP, store: {Bazaar.Idempotency.Cachex, :idempotency}
```

Any other backend implements the four callbacks of `Bazaar.Idempotency.Store`: `fetch/2`, `reserve/3`, `put/3` and `release/2`. `reserve/3` has to be atomic, because that's what stops two identical requests in flight from both running.

Only 2xx and 4xx responses are recorded; a 5xx releases the key so the platform's retry runs the action again. A reservation left behind by a request that crashed before responding is taken over after `:reservation_ttl` (30 seconds by default).

## VerifySignature

Platforms may sign their requests with RFC 9421 HTTP message signatures and publish their public keys as a JWK set in their profile. `Bazaar.Plugs.VerifySignature` fetches the profile named in `UCP-Agent`, picks the key the signature's `keyid` names, and verifies the signature and the `Content-Digest` against the raw body. Unsigned requests pass unless `required: true`, since the spec leaves inbound verification to the business and the conformance suite sends none.

It needs the raw body bytes, so install the body reader on `Plug.Parsers`:

```elixir
# endpoint.ex
plug Plug.Parsers,
  parsers: [:json],
  json_decoder: Jason,
  body_reader: {Bazaar.Plugs.RawBody, :read_body, []}

# router.ex
plug Bazaar.Plugs.VerifySignature,
  http_client: &MyApp.Http.get/1,      # optional; your shop's http_client/0 supplies one
  cache: MyApp.ProfileCache.map(),     # optional, fetch each platform's keys once
  required: false,                     # 401 for unsigned requests when true
  max_age: 300                         # seconds a signature's created may be in the past
```

A verified request carries `conn.assigns.ucp_signature` with the `keyid` and `created`. Failures answer 401 with an error document: `invalid_signature`, `signer_unknown` or `signature_required`.

## Plug Order

```elixir
pipeline :ucp do
  plug Bazaar.Plugs.UCPHeaders       # headers and version first, so rejections carry a request id
  plug Bazaar.Plugs.Idempotency      # replay before validation and before the action
  plug Bazaar.Plugs.VerifySignature  # needs the profile URL from UCPHeaders
  plug Bazaar.Plugs.ValidateRequest
end
```

## Error Documents

Both plugs, and `Bazaar.Phoenix.Controller`, render errors with `Bazaar.Errors.response/2`: the UCP error response (`ucp.status: "error"` plus `messages[]`) for UCP routes and the ACP `Error` object for ACP routes.

## Logging

Use request IDs for tracing:

```elixir
def create_checkout(params, conn) do
  Logger.metadata(request_id: conn.assigns[:ucp_request_id])
  Logger.info("Creating checkout", params: params)
  # ...
end
```

## Next Steps

- [Handlers Guide](handlers.md) - Access plug data in handlers
- [Testing Guide](testing.md) - Test with plugs

## SignResponse

Signs every successful response with an RFC 9421 signature over `@status`, `Content-Digest` and `Content-Type`, which the spec recommends for checkout completion and payment responses. Platforms verify against the public key you publish as `"keys"` in `business_profile/0`, so pass the same key:

```elixir
plug Bazaar.Plugs.SignResponse, key: &MyApp.Signing.key/0
```

`key:` takes a `Bazaar.Signing.Key` or a zero-arity function (for a key loaded at boot); `statuses:` narrows what gets signed (default `200..299`).
