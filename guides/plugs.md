# Plugs Guide

Ucphi provides three plugs for production-ready UCP implementations:

| Plug | Purpose |
|------|---------|
| `UCPHeaders` | Extract and manage UCP-specific headers |
| `ValidateRequest` | Validate request bodies against schemas |
| `Idempotency` | Handle retry safety with idempotency keys |

## Setting Up Plugs

Add plugs to your router pipeline:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Ucphi.Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  # UCP-specific pipeline
  pipeline :ucp do
    plug Ucphi.Plugs.UCPHeaders
    plug Ucphi.Plugs.ValidateRequest
    plug Ucphi.Plugs.Idempotency
  end

  scope "/" do
    pipe_through [:api, :ucp]
    ucphi_routes "/", MyApp.Commerce.Handler
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
plug Ucphi.Plugs.UCPHeaders
```

### Accessing Headers in Handler

```elixir
def create_checkout(params, conn) do
  # Agent making the request
  agent = conn.assigns[:ucp_agent]
  # e.g., "google-shopping/1.0"

  # Unique request ID (for logging/tracing)
  request_id = conn.assigns[:ucp_request_id]
  # e.g., "req_abc123..."

  # Request signature (for verification)
  signature = conn.assigns[:ucp_signature]

  # ... rest of implementation
end
```

### Request ID Format

Generated request IDs follow the format:
```
req_[base32-encoded-random-bytes]
```

Example: `req_mfrggzdfmy2tqnzy`

### Example Request

```bash
curl -X POST http://localhost:4000/checkout-sessions \
  -H "Content-Type: application/json" \
  -H "UCP-Agent: my-shopping-agent/1.0" \
  -H "UCP-Request-ID: req_custom123" \
  -d '{"currency": "USD", "line_items": [...]}'
```

Response will include:
```
UCP-Request-ID: req_custom123
```

## ValidateRequest

Validates request bodies against Ucphi schemas before reaching your handler.

### What It Does

1. Checks if the current action has a schema
2. Validates params against the schema
3. Returns 422 with errors if invalid
4. Stores validated data in `conn.assigns`

### Usage

```elixir
plug Ucphi.Plugs.ValidateRequest
```

### Default Schemas

| Action | Schema |
|--------|--------|
| `create_checkout` | `Ucphi.Schemas.CheckoutSession` |
| `update_checkout` | `Ucphi.Schemas.CheckoutSession` |

### Custom Schemas

Override or add schemas:

```elixir
plug Ucphi.Plugs.ValidateRequest,
  schemas: %{
    create_checkout: MyApp.Schemas.CustomCheckout,
    my_custom_action: MyApp.Schemas.CustomSchema
  }
```

### Accessing Validated Data

After validation, data is available in assigns:

```elixir
def create_checkout(params, conn) do
  if conn.assigns[:ucphi_validated] do
    # Use pre-validated data
    validated = conn.assigns[:ucphi_data]
    # validated is already an Ecto struct
  else
    # Validate manually (plug wasn't used or no schema)
    changeset = Ucphi.Schemas.CheckoutSession.new(params)
  end
end
```

### Validation Error Response

Invalid requests return 422 with:

```json
{
  "error": "validation_error",
  "message": "Validation failed",
  "details": [
    {"field": "currency", "message": "can't be blank"},
    {"field": "line_items", "message": "can't be blank"}
  ]
}
```

## Idempotency

Handles retry safety by caching responses for repeated requests.

### What It Does

1. Checks for `Idempotency-Key` header
2. If key exists in cache, returns cached response
3. If new key, processes request and caches response
4. Only caches successful responses (2xx status)

### Usage

```elixir
plug Ucphi.Plugs.Idempotency
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `:cache` | `ETSCache` | Cache backend module |
| `:ttl` | `86400` | Cache TTL in seconds (24h) |
| `:header` | `"idempotency-key"` | Header name |

```elixir
plug Ucphi.Plugs.Idempotency,
  ttl: 3600,  # 1 hour
  header: "x-idempotency-key"
```

### How It Works

**First request:**
```bash
curl -X POST http://localhost:4000/checkout-sessions \
  -H "Idempotency-Key: unique-key-123" \
  -H "Content-Type: application/json" \
  -d '{"currency": "USD", ...}'
```

Response:
```
HTTP/1.1 201 Created
Idempotency-Key: unique-key-123
Content-Type: application/json

{"id": "checkout_abc", ...}
```

**Retry with same key:**
```bash
curl -X POST http://localhost:4000/checkout-sessions \
  -H "Idempotency-Key: unique-key-123" \
  -H "Content-Type: application/json" \
  -d '{"currency": "USD", ...}'
```

Response (from cache):
```
HTTP/1.1 201 Created
Idempotency-Key: unique-key-123
Idempotency-Replay: true
Content-Type: application/json

{"id": "checkout_abc", ...}
```

### Cache Key Structure

Keys are scoped by method and path:
```
POST:/checkout-sessions:unique-key-123
```

This means the same idempotency key can be used for different endpoints.

### Custom Cache Backend

For production, use Redis or another distributed cache:

```elixir
defmodule MyApp.RedisIdempotencyCache do
  def get(key) do
    case Redix.command(:redix, ["GET", key]) do
      {:ok, nil} -> :miss
      {:ok, data} -> {:ok, :erlang.binary_to_term(data)}
    end
  end

  def put(key, response, ttl) do
    data = :erlang.term_to_binary(response)
    Redix.command(:redix, ["SETEX", key, ttl, data])
    :ok
  end

  def delete(key) do
    Redix.command(:redix, ["DEL", key])
    :ok
  end
end

# In router:
plug Ucphi.Plugs.Idempotency,
  cache: MyApp.RedisIdempotencyCache
```

### When to Use Idempotency Keys

Clients should send idempotency keys for:
- Creating checkouts
- Completing payments
- Any operation that shouldn't be duplicated

## Plug Order

Order matters! Recommended sequence:

```elixir
pipeline :ucp do
  # 1. Extract headers first (for logging)
  plug Ucphi.Plugs.UCPHeaders

  # 2. Check idempotency (may return cached response)
  plug Ucphi.Plugs.Idempotency

  # 3. Validate request body (if not cached)
  plug Ucphi.Plugs.ValidateRequest
end
```

## Complete Example

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use Ucphi.Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_query_params
  end

  pipeline :ucp do
    plug Ucphi.Plugs.UCPHeaders
    plug Ucphi.Plugs.Idempotency, ttl: 86400
    plug Ucphi.Plugs.ValidateRequest
  end

  # Public discovery (no validation needed)
  scope "/" do
    pipe_through :api

    get "/.well-known/ucp", Ucphi.Phoenix.Controller, :discovery,
      assigns: %{ucphi_handler: MyApp.Commerce.Handler}
  end

  # Protected UCP endpoints
  scope "/" do
    pipe_through [:api, :ucp]

    post "/checkout-sessions", Ucphi.Phoenix.Controller, :create_checkout,
      assigns: %{ucphi_handler: MyApp.Commerce.Handler}

    get "/checkout-sessions/:id", Ucphi.Phoenix.Controller, :get_checkout,
      assigns: %{ucphi_handler: MyApp.Commerce.Handler}

    # ... other routes
  end
end
```

## Logging and Debugging

Use request IDs for tracing:

```elixir
def create_checkout(params, conn) do
  request_id = conn.assigns[:ucp_request_id]

  Logger.metadata(request_id: request_id)
  Logger.info("Creating checkout", params: params)

  # ... implementation
end
```

## Next Steps

- [Handlers Guide](handlers.md) - Access plug data in handlers
- [Testing Guide](testing.md) - Test with plugs
