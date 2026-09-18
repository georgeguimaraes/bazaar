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
| Update | `PUT /checkout-sessions/:id` | `POST /checkout_sessions/:id` |
| Complete | `POST /checkout-sessions/:id/complete` | `POST /checkout_sessions/:id/complete` |
| Cancel | `POST /checkout-sessions/:id/cancel` | `POST /checkout_sessions/:id/cancel` |

ACP has no discovery, catalog, cart or order routes; `bazaar_routes ... protocol: :acp` mounts the five above.

### Status Values

| Internal (UCP) | ACP |
|----------------|-----|
| `incomplete` | `not_ready_for_payment` |
| `requires_escalation` | `authentication_required` |
| `ready_for_complete` | `ready_for_payment` |
| `complete_in_progress` | `in_progress` |
| `completed` | `completed` |
| `canceled` | `canceled` |

### Requests

ACP requests are translated into the UCP shape your handler reads (`Bazaar.Protocol.Transformer.transform_request/2`):

| ACP | UCP |
|-----|-----|
| `line_items[{id, quantity}]` (the RFC also spells it `items`) | `line_items[{item: {id}, quantity}]` |
| `buyer` | `buyer` (same fields) |
| `fulfillment_details{name, phone_number, address}` | one `shipping` method whose selected destination is the address (see the address table), with `first_name`, `last_name` and `phone_number` |
| `selected_fulfillment_options[{option_id, item_ids}]` | that method's group `selected_option_id` |
| `discounts.codes` and the deprecated `coupons` | `discounts.codes` |
| `payment_data{handler_id, instrument, billing_address}` (complete) | `payment.instruments[instrument + handler_id + billing_address]` |
| `capabilities`, `locale`, `metadata`, `authentication_result`, ... | dropped |

ACP's `item_ids` name items, UCP groups name line items, so a selection applies to the whole shipping method (ACP models one shipping group).

### Responses

The UCP checkout document your handler returns becomes an ACP checkout session (`transform_response/2`), validated in bazaar's tests against the bundled `2026-01-30` schema:

| UCP | ACP |
|-----|-----|
| `line_items[].item{id, title, price}` | `line_items[].item{id, name, unit_amount}` |
| `totals[{type, amount}]` | `totals[{type, display_text, amount}]` (`display_text` from the type) |
| `fulfillment.methods[].groups[].options` | `fulfillment_options[{type, id, title, totals}]` |
| selected group option | `selected_fulfillment_options[{type, option_id, item_ids}]` |
| selected destination | `fulfillment_details{name, phone_number, address}` |
| `messages[]` | `messages[]` with ACP's code enum (`payment_failed` → `payment_declined`, `invalid_request` → `invalid`, `quantity_adjusted` → `low_stock`), severity (`unrecoverable` → `critical`, `requires_buyer_input` → `high`, ...), `content_type` and `param` |
| `buyer` | `email`, `first_name`, `last_name`, `full_name`, `phone_number` only |
| `discounts.applied[{code, title, amount}]` | `discounts.applied[{id, code, coupon{id, name}, amount, allocations}]` |
| `links` | `links` (`terms_of_service` → `terms_of_use`, types ACP doesn't know dropped) |
| `ucp.payment_handlers` | `capabilities.payment.handlers`, see below |
| `order{id, permalink_url}` | `order{id, checkout_session_id, permalink_url}` |
| `ucp`, `fulfillment`, `payment` | not present; `protocol.version` is `2026-01-30` |

**Payment handlers.** ACP describes a handler with more than UCP does (`spec`, `psp`, `requires_delegate_payment`, `requires_pci_compliance`, `config_schema`, `instrument_schemas`, `config`). Registry entries in your checkout's `ucp.payment_handlers` that carry those fields are advertised to ACP agents; entries without them are left out, and `capabilities` is empty when none qualify.

### Address Fields

| UCP | ACP |
|-----|-----|
| `street_address` | `line_one` |
| `extended_address` | `line_two` |
| `address_locality` | `city` |
| `address_region` | `state` |
| `address_country` | `country` |
| `postal_code` | `postal_code` |
| `first_name` + `last_name` | `name` |

ACP requires `name`, `line_one`, `city`, `state`, `country` and `postal_code` on every address; fields UCP has no value for are sent as `""`, as the ACP examples do.

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
curl -X POST http://localhost:4000/checkout-sessions \
  -H "Content-Type: application/json" \
  -d '{"currency":"USD","line_items":[{"item":{"id":"sample"},"quantity":1}]}'
```

The response is the UCP checkout document (`ucp`, `id`, `status: "ready_for_complete"`, `line_items`, `totals`, ...).

### ACP Request

```bash
curl -X POST http://localhost:4000/acp/checkout_sessions \
  -H "Content-Type: application/json" \
  -d '{"currency":"USD","line_items":[{"id":"sample","quantity":1}],"buyer":{"email":"agent@example.com"},"capabilities":{}}'
```

The response is an ACP checkout session (`protocol`, `id`, `status: "ready_for_payment"`, `line_items` with `item.unit_amount`, `totals` with `display_text`, `fulfillment_options`, `capabilities`, ...).

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
