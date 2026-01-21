# Protocols Guide

Bazaar supports two commerce protocols, allowing your store to serve multiple AI agent ecosystems from a single handler implementation.

## Supported Protocols

| Protocol | Used By | Discovery |
|----------|---------|-----------|
| **UCP** (Universal Commerce Protocol) | Google Shopping agents | `/.well-known/ucp` |
| **ACP** (Agentic Commerce Protocol) | OpenAI Operator, Stripe | Centralized registry |

## Internal Format: UCP

Bazaar uses **UCP as its internal/canonical format**. Your handler always works with UCP field names and status values, regardless of which protocol the client uses:

```
ACP Request → [transform to UCP] → Your Handler → [transform to ACP] → ACP Response
UCP Request → Your Handler → UCP Response (no transformation)
```

This means you write your handler once using UCP conventions, and Bazaar automatically translates for ACP clients.

## Protocol Differences

### URL Patterns

| Operation | UCP | ACP |
|-----------|-----|-----|
| Create | `POST /checkout-sessions` | `POST /checkout_sessions` |
| Get | `GET /checkout-sessions/:id` | `GET /checkout_sessions/:id` |
| Update | `PATCH /checkout-sessions/:id` | `POST /checkout_sessions/:id` |
| Complete | `POST /checkout-sessions/:id/actions/complete` | `POST /checkout_sessions/:id/complete` |
| Cancel | `DELETE /checkout-sessions/:id` | `POST /checkout_sessions/:id/cancel` |

### Status Values

| Internal (UCP) | ACP |
|----------------|-----|
| `incomplete` | `not_ready_for_payment` |
| `requires_escalation` | `authentication_required` |
| `ready_for_complete` | `ready_for_payment` |
| `complete_in_progress` | `in_progress` |
| `completed` | `completed` |
| `canceled` | `canceled` |

### Address Fields

| UCP | ACP |
|-----|-----|
| `street_address` | `line_one` |
| `extended_address` | `line_two` |
| `address_locality` | `city` |
| `address_region` | `state` |
| `address_country` | `country` |
| `postal_code` | `postal_code` |

### Item Fields

| UCP | ACP |
|-----|-----|
| `items` | `line_items` |
| `sku` | `product.id` |
| `name` | `product.name` |
| `price` | `base_amount` |

## Router Configuration

### UCP Only (Default)

```elixir
scope "/" do
  pipe_through :api
  bazaar_routes "/", MyApp.UCPHandler
end
```

### ACP Only

```elixir
scope "/" do
  pipe_through :api
  bazaar_routes "/", MyApp.UCPHandler, protocol: :acp
end
```

### Both Protocols

```elixir
scope "/" do
  pipe_through :api

  # UCP at /ucp (Google agents)
  bazaar_routes "/ucp", MyApp.UCPHandler

  # ACP at /acp (OpenAI/Stripe agents)
  bazaar_routes "/acp", MyApp.UCPHandler, protocol: :acp
end
```

## Discovery

### UCP Discovery

UCP uses open discovery via `/.well-known/ucp`. Bazaar automatically generates this endpoint from your handler's `business_profile/0` and `capabilities/0`.

```bash
curl http://localhost:4000/.well-known/ucp
```

### ACP Discovery

ACP uses centralized discovery through Stripe's merchant registry. There's no `/.well-known` endpoint for ACP. Merchants register their ACP endpoints directly with Stripe/OpenAI.

When using `protocol: :acp`, Bazaar does not generate a discovery endpoint.

## Testing Both Protocols

### UCP Request

```bash
curl -X POST http://localhost:4000/ucp/checkout-sessions \
  -H "Content-Type: application/json" \
  -d '{
    "currency": "usd",
    "items": [{"sku": "PROD-001", "quantity": 1}]
  }'
```

Response uses UCP format:
```json
{
  "id": "...",
  "status": "incomplete",
  "items": [...]
}
```

### ACP Request

```bash
curl -X POST http://localhost:4000/acp/checkout_sessions \
  -H "Content-Type: application/json" \
  -d '{
    "currency": "usd",
    "line_items": [{"product": {"id": "PROD-001"}, "quantity": 1}]
  }'
```

Response uses ACP format:
```json
{
  "id": "...",
  "status": "not_ready_for_payment",
  "line_items": [...]
}
```

## Handler Implementation

Your handler uses UCP format regardless of the protocol:

```elixir
defmodule MyApp.UCPHandler do
  use Bazaar.Handler

  @impl true
  def create_checkout(params, _conn) do
    # params are ALWAYS in UCP format
    # - params["items"] (not "line_items")
    # - params["items"][0]["sku"] (not "product.id")

    {:ok, %{
      "id" => "checkout_123",
      "status" => "incomplete",  # Always use UCP status
      "items" => [...]           # Always use "items" key
    }}
  end

  @impl true
  def update_checkout(id, params, _conn) do
    # Buyer addresses are in UCP format
    # - params["buyer"]["shipping_address"]["street_address"]
    # - params["buyer"]["shipping_address"]["address_locality"]

    {:ok, updated_checkout}
  end
end
```

Bazaar handles the transformation automatically:
- ACP `line_items` → UCP `items` (before your handler)
- UCP `incomplete` → ACP `not_ready_for_payment` (after your handler)

## Validation

Each protocol uses its own validation schemas:

- **UCP**: `Bazaar.Schemas.Ucp.*`
- **ACP**: `Bazaar.Schemas.Acp.*`

Bazaar validates incoming requests against the appropriate schema based on the protocol option.

## Next Steps

- [Getting Started](getting-started.md) - Build your first merchant
- [Handlers](handlers.md) - Implement commerce logic
- [Testing](testing.md) - Test your implementation
