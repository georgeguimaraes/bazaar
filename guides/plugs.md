# Plugs Guide

Bazaar provides plugs for UCP implementations:

| Plug | Purpose |
|------|---------|
| `UCPHeaders` | Read the UCP headers and negotiate the protocol version |
| `Idempotency` | Replay responses for repeated `Idempotency-Key` requests |
| `ValidateRequest` | Validate request bodies against the generated schemas |
| `ValidateResponse` | Validate response bodies against the generated schemas |

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
    plug Bazaar.Plugs.UCPHeaders
    plug Bazaar.Plugs.Idempotency
  end

  scope "/" do
    pipe_through :ucp
    bazaar_routes "/", MyApp.UCPHandler
  end
end
```

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

The lookup runs before the action, so replaying a completed checkout's completion still returns the original response. The plug fingerprints `conn.body_params`, so it must run after `Plug.Parsers` (any Phoenix endpoint does this). Two identical requests in flight at the same time both run; the record is written when the first response is sent.

### Usage

```elixir
plug Bazaar.Plugs.Idempotency
plug Bazaar.Plugs.Idempotency, store: {MyApp.RedisIdempotency, :orders}, methods: ["POST"]
```

### Stores

`Bazaar.Idempotency.ETS` keeps records in memory for the life of the process, which suits a single node and development. For several nodes, implement `Bazaar.Idempotency.Store` (`fetch/2` and `put/3`) on top of shared storage and pass it with `:store`.

## Plug Order

```elixir
pipeline :ucp do
  plug Bazaar.Plugs.UCPHeaders    # headers and version first, so rejections carry a request id
  plug Bazaar.Plugs.Idempotency   # replay before validation and before the action
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
