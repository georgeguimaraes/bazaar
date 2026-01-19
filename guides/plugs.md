# Plugs Guide

Bazaar provides plugs for UCP implementations:

| Plug | Purpose |
|------|---------|
| `UCPHeaders` | Extract and manage UCP-specific headers |
| `Idempotency` | Extract idempotency keys for retry safety |

## Setting Up Plugs

Add plugs to your router pipeline:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Bazaar.Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :ucp do
    plug Bazaar.Plugs.UCPHeaders
    plug Bazaar.Plugs.Idempotency
  end

  scope "/" do
    pipe_through [:api, :ucp]
    bazaar_routes "/", MyApp.UCPHandler
  end
end
```

## UCPHeaders

Extracts UCP-specific headers and manages request IDs.

### What It Does

1. Extracts `UCP-Agent` header (agent identifier)
2. Extracts `UCP-Request-ID` header (or generates one)
3. Extracts `Request-Signature` header (for verification)
4. Adds `UCP-Request-ID` to response headers

### Usage

```elixir
plug Bazaar.Plugs.UCPHeaders
```

### Accessing Headers in Handler

```elixir
def create_checkout(params, conn) do
  agent = conn.assigns[:ucp_agent]        # e.g., "google-shopping/1.0"
  request_id = conn.assigns[:ucp_request_id]  # e.g., "req_abc123..."
  signature = conn.assigns[:ucp_signature]

  # ...
end
```

### Request ID Format

Generated request IDs follow the format: `req_[base32-encoded-random-bytes]`

Example: `req_mfrggzdfmy2tqnzy`

## Idempotency

Extracts idempotency keys from requests for retry safety.

### What It Does

1. Extracts `Idempotency-Key` header
2. Stores key in `conn.assigns.idempotency_key`
3. Echoes key in response header

### Usage

```elixir
plug Bazaar.Plugs.Idempotency
```

### Accessing the Key

```elixir
def create_checkout(params, conn) do
  case conn.assigns[:idempotency_key] do
    nil ->
      # No idempotency requested
      do_create(params)

    key ->
      # Check your cache, return cached response or create new
      case MyApp.IdempotencyCache.get(key) do
        {:ok, cached} -> {:ok, cached}
        :miss ->
          {:ok, checkout} = do_create(params)
          MyApp.IdempotencyCache.put(key, checkout)
          {:ok, checkout}
      end
  end
end
```

### Implementing Idempotency Caching

Bazaar extracts the header but **you must implement caching** for production use. Here's a Redis example:

```elixir
defmodule MyApp.IdempotencyCache do
  @ttl 86_400  # 24 hours

  def get(key) do
    case Redix.command(:redix, ["GET", cache_key(key)]) do
      {:ok, nil} -> :miss
      {:ok, data} -> {:ok, Jason.decode!(data)}
    end
  end

  def put(key, response) do
    data = Jason.encode!(response)
    Redix.command(:redix, ["SETEX", cache_key(key), @ttl, data])
    :ok
  end

  defp cache_key(key), do: "idempotency:#{key}"
end
```

### When to Use Idempotency

AI agents should send idempotency keys for:
- Creating checkouts
- Completing payments
- Any operation that shouldn't be duplicated on retry

## Plug Order

Recommended sequence:

```elixir
pipeline :ucp do
  plug Bazaar.Plugs.UCPHeaders    # Extract headers first (for logging)
  plug Bazaar.Plugs.Idempotency   # Extract idempotency key
end
```

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
