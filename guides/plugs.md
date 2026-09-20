# Plugs Guide

One plug is the whole UCP request path:

```elixir
pipeline :ucp do
  plug :accepts, ["json"]
  plug Bazaar.Plugs.UCP
end
```

`Bazaar.Plugs.UCP` runs four steps in order, reading what it needs from the handler the route mounts and its shop:

| Step | What it does |
|------|--------------|
| `UCPHeaders` | Reads `UCP-Agent`, negotiates the protocol version |
| `Idempotency` | Replays a repeated `Idempotency-Key`, headers and all |
| `VerifySignature` | Verifies a signed request against the platform's published keys, using the shop's `http_client/0` |
| `SignResponse` | Signs the answer with the shop's `signing_key/0`, when it has one |

`verify_signatures: false` and `sign_responses: false` switch off the last two; every other option (`version:`, `store:`, `required:`, `max_age:`, `statuses:`) passes through. The four are public plugs, so a pipeline that needs a different order or something in between can compose its own.

Two more are separate, since they take per-action schema configuration:

| Plug | Purpose |
|------|---------|
| `ValidateRequest` | Validate request bodies against the generated schemas |
| `ValidateResponse` | Validate response bodies against the spec's JSON Schemas (needs `jsv`) |

## Setting Up Plugs

The pipeline above and one line in your endpoint, which signature checks need because a `Content-Digest` covers the body exactly as sent:

```elixir
# lib/my_app_web/endpoint.ex
plug Plug.Parsers,
  parsers: [:json],
  pass: ["*/*"],
  json_decoder: Jason,
  body_reader: {Bazaar.Plugs.RawBody, :read_body, []}

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
    bazaar_routes "/", MyApp.CommerceHandler
  end
end
```

Nothing goes in your supervision tree: the in-memory stores start themselves the first time a handler uses them. The sections below describe each step, for when you compose your own pipeline.

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

## SignResponse

Signs every successful response with an RFC 9421 signature over `@status`, `Content-Digest` and `Content-Type`, which the spec recommends for checkout completion and payment responses. Platforms verify against the public key you publish as `"keys"` in `business_profile/0`, so pass the same key:

```elixir
plug Bazaar.Plugs.SignResponse, key: &MyApp.Signing.key/0
```

`key:` takes a `Bazaar.Signing.Key` or a zero-arity function (for a key loaded at boot); `statuses:` narrows what gets signed (default `200..299`).

## Plug Order

`Bazaar.Plugs.UCP` runs them in the order that matters: headers first so rejections carry a request id, idempotency next so a replay skips everything after it, verification once the profile URL is known, and response signing last so replays carry the signature they were first sent with. Composing your own, keep that order:

```elixir
pipeline :ucp do
  plug Bazaar.Plugs.UCPHeaders
  plug Bazaar.Plugs.Idempotency
  plug Bazaar.Plugs.VerifySignature
  plug Bazaar.Plugs.ValidateRequest
  plug Bazaar.Plugs.SignResponse, key: &MyApp.Shop.signing_key/0
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
