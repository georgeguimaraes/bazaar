# Bazaar

**Open your store to AI agents.** Elixir SDK for [UCP](https://ucp.dev) and [ACP](https://github.com/agentic-commerce-protocol/acp-spec).

Bazaar helps you build commerce APIs in Elixir/Phoenix that work with both Google Shopping agents (UCP) and OpenAI/Stripe agents (ACP) from a single handler.

> [!TIP]
> [examples/flower_shop](https://github.com/georgeguimaraes/bazaar/tree/main/examples/flower_shop) is a runnable merchant that passes the official UCP conformance suite, and CI runs that suite against it on every push.

## Supported Protocols

| Protocol | Used By | Spec |
|----------|---------|------|
| **UCP** (Universal Commerce Protocol) | Google Shopping agents | [ucp.dev](https://ucp.dev) |
| **ACP** (Agentic Commerce Protocol) | OpenAI Operator, Stripe | [GitHub](https://github.com/agentic-commerce-protocol/acp-spec) |

Both protocols enable AI agents to discover what your store offers, create and manage shopping carts, complete checkouts, and track orders.

UCP was announced by Google at NRF 2026, co-developed with Shopify, Walmart, Etsy, and Target. ACP is backed by OpenAI and Stripe.

## Features

- **Dual Protocol Support**: Serve both UCP and ACP clients from one handler with automatic request/response translation
- **Generated UCP Schemas**: Smelter-generated Ecto schemas from official UCP JSON Schemas
- **ACP Schema Validation**: JSON Schema validation for ACP checkout sessions and delegate payment, plus an Ecto schema for the OpenAI product feed
- **Phoenix Router Macro**: Mount UCP and ACP routes with a single line each
- **Handler Behaviour**: Write commerce logic once, serve both protocols
- **Built-in Plugs**: Request validation, idempotency, and UCP headers
- **Auto-generated Discovery**: `/.well-known/ucp` endpoint from your handler
- **Protocol Transformer**: Automatic field/status mapping between UCP and ACP formats
- **Checkout Document Builder**: `Bazaar.Checkout` merges updates with the spec's carry-over rules and builds the document (totals, fulfillment, discounts, status) from your prices, stock and rates
- **Business Logic Helpers**: Currency conversion, message factories, order creation, catalog filters and pagination

## How It Works

Bazaar uses UCP as its internal format. Your handler always works with UCP field names and status values, regardless of which protocol the client uses:

```
UCP Request → Bazaar Router → Your Handler → UCP Response
ACP Request → [transform to UCP] → Your Handler → [transform to ACP] → ACP Response
```

Bazaar handles the HTTP/JSON plumbing. You write the commerce logic.

| Bazaar | You |
|--------|-----|
| Routes requests from UCP and ACP agents | Write business logic |
| Transforms between protocol formats | Query your database |
| Validates request/response structure | Calculate prices, tax, shipping |
| Handles UCP headers and discovery | Integrate with payment/fulfillment |

## Architecture

```
lib/bazaar/
├── schemas/
│   ├── ucp/           # Generated UCP schemas (from Smelter)
│   │   ├── shopping/  # Checkout, Order, Payment types
│   │   ├── capability/# Capability definitions
│   │   └── ucp/       # Discovery profile, response types
│   └── acp/           # ACP schemas: OpenAI product feed
├── protocol.ex        # UCP/ACP status mappings
├── protocol/
│   └── transformer.ex # Request/response translation between protocols
├── validator.ex       # Schema validation (UCP via JSV, ACP via JSV/$defs, product feed via Ecto)
├── checkout.ex        # Checkout state, update rules and document builder
├── order.ex           # Order documents: from a checkout, platform updates, fulfillment events
├── message.ex         # Business logic: error/warning/info factories
├── fulfillment.ex     # Fulfillment types and default configuration
├── handler.ex         # Handler behaviour
├── phoenix/           # Router and controller
├── plugs/             # Request validation, headers, idempotency
├── webhook.ex         # Order event delivery with retries
├── webhook/           # Event struct and retry schedule
├── signing/           # Signing keys and RFC 9421 HTTP message signatures
└── platform.ex        # Platform profile lookup (webhook URL)
```

## Installation

Add `bazaar` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bazaar, "~> 0.3"}
  ]
end
```

## Quick Start

### Step 1: Create a Handler

The handler defines your store's capabilities and commerce logic:

```elixir
defmodule MyApp.CommerceHandler do
  use Bazaar.Handler

  @impl true
  def capabilities, do: [:checkout, :orders]

  @impl true
  def business_profile do
    %{
      "name" => "My Awesome Store",
      "description" => "We sell amazing products"
    }
  end

  @impl true
  def create_checkout(params, _conn) do
    # params already validated by Bazaar
    {:ok, %{"id" => "chk_123", "status" => "incomplete", ...}}
  end

  @impl true
  def get_checkout(id, _conn) do
    {:ok, checkout} or {:error, :not_found}
  end

  # ... other callbacks: update_checkout, cancel_checkout, get_order, cancel_order
end
```

### Step 2: Mount Routes

Add UCP and ACP routes to your Phoenix router:

```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router
  use Bazaar.Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
    plug Bazaar.Plugs.UCP   # UCP headers, version negotiation, idempotent replay
  end

  scope "/" do
    pipe_through :api

    # UCP routes (Google agents)
    bazaar_routes "/", MyApp.CommerceHandler

    # ACP routes (OpenAI/Stripe agents)
    bazaar_routes "/acp", MyApp.CommerceHandler, protocol: :acp
  end
end
```

UCP endpoints:

| Method | Path | Description |
|--------|------|-------------|
| GET | `/.well-known/ucp` | Discovery endpoint |
| POST | `/checkout-sessions` | Create checkout |
| GET | `/checkout-sessions/:id` | Get checkout |
| PUT | `/checkout-sessions/:id` | Update checkout |
| POST | `/checkout-sessions/:id/complete` | Complete checkout |
| POST | `/checkout-sessions/:id/cancel` | Cancel checkout |
| GET | `/orders/:id` | Get order |
| POST | `/orders/:id/actions/cancel` | Cancel order |
| POST | `/carts` | Create cart (with `:cart`) |
| GET | `/carts/:id` | Get cart (with `:cart`) |
| PUT | `/carts/:id` | Update cart (with `:cart`) |
| POST | `/carts/:id/cancel` | Cancel cart (with `:cart`) |
| POST | `/catalog/search` | Search products (with `:catalog`) |
| POST | `/catalog/lookup` | Look up products by id (with `:catalog`) |
| POST | `/catalog/product` | Get one product (with `:catalog`) |
| POST | `/webhooks/ucp` | Receive webhooks |

ACP endpoints:

| Method | Path | Description |
|--------|------|-------------|
| POST | `/acp/checkout_sessions` | Create checkout |
| GET | `/acp/checkout_sessions/:id` | Get checkout |
| POST | `/acp/checkout_sessions/:id` | Update checkout |
| POST | `/acp/checkout_sessions/:id/complete` | Complete checkout |
| POST | `/acp/checkout_sessions/:id/cancel` | Cancel checkout |

`bazaar_routes` is a convenience, not a requirement. If you'd rather own the routes and controllers, skip it: build the discovery document with `Bazaar.DiscoveryProfile.from_handler(MyApp.CommerceHandler, base_url: url)`, call the handler callbacks from your own actions, and keep using the plugs and helpers. You can also mix the two, which is what [examples/flower_shop](https://github.com/georgeguimaraes/bazaar/tree/main/examples/flower_shop) does: `bazaar_routes` for the standard routes and a few hand-written ones for what the conformance suite needs beyond the spec.

### Step 3: Test It

```bash
# UCP discovery
curl http://localhost:4000/.well-known/ucp

# Create a checkout via UCP
curl -X POST http://localhost:4000/checkout-sessions \
  -H "Content-Type: application/json" -d '{"items": [...]}'

# Create a checkout via ACP
curl -X POST http://localhost:4000/acp/checkout_sessions \
  -H "Content-Type: application/json" -d '{"line_items": [...]}'
```

## Protocol Differences

Bazaar automatically handles the differences between UCP and ACP. Your handler code stays the same:

| Aspect | UCP | ACP |
|--------|-----|-----|
| URL style | `/checkout-sessions` | `/checkout_sessions` |
| Update method | `PUT` | `POST` |
| Cancel method | `POST /cancel` | `POST /cancel` |
| Discovery | `/.well-known/ucp` | None |
| Status: incomplete | `incomplete` | `not_ready_for_payment` |
| Status: ready | `ready_for_complete` | `ready_for_payment` |
| Address: street | `street_address` | `line_one` |
| Address: city | `address_locality` | `city` |
| Items key | `items` | `line_items` |

## Validation

Bazaar bundles schema validation for both protocols:

```elixir
# UCP schemas (via JSV against bundled JSON Schemas)
Bazaar.Validator.validate(data, :checkout)
Bazaar.Validator.validate(data, :cart)
Bazaar.Validator.validate(data, :order)
Bazaar.Validator.validate(data, :profile)
Bazaar.Validator.validate(data, :catalog_search_response)
Bazaar.Validator.validate(data, :catalog_lookup_response)
Bazaar.Validator.validate(data, :catalog_product_response)

# ACP schemas (via JSV against bundled JSON Schemas with $defs)
Bazaar.Validator.validate(data, :checkout_session)
Bazaar.Validator.validate(data, :checkout_create_req)
Bazaar.Validator.validate(data, :checkout_complete_req)
Bazaar.Validator.validate(data, :delegate_payment_req)
Bazaar.Validator.validate(data, :delegate_payment_resp)

# OpenAI product feed (via Ecto embedded schema)
Bazaar.Validator.validate(data, :openai_product_feed)

# List all available schemas
Bazaar.Validator.available_schemas()
# => %{ucp: [:checkout, :order, :profile, :error_response, :catalog_search_response, ...], acp: [...]}
```

UCP schemas track the [UCP spec](https://ucp.dev) (currently `2026-08-25`). ACP schemas track the [open ACP repo](https://github.com/agentic-commerce-protocol/agentic-commerce-protocol) (currently `2026-01-30`).

## Capabilities

| Capability | Description | Callbacks |
|------------|-------------|-----------|
| `:checkout` | Checkout sessions | `create_checkout`, `get_checkout`, `update_checkout`, `cancel_checkout` |
| `:cart` | Carts before checkout, convertible with `cart_id` | `create_cart`, `get_cart`, `update_cart`, `cancel_cart` (see `Bazaar.Cart`) |
| `:orders` | Order tracking | `get_order`, `cancel_order` |
| `:fulfillment` | Shipping and pickup | Extends checkout/order with fulfillment options |
| `:identity` | User identity linking | `link_identity` |
| `:catalog` | Product discovery | `search_products`, `lookup_products`, `get_product` (see `Bazaar.Catalog` for filters, pagination and option availability) |
| `:discount` | Discount codes | Extends checkout with discount support |

## Schemas

UCP schemas are generated from official JSON Schemas using [Smelter](https://github.com/georgeguimaraes/smelter):

```elixir
# Validate checkout response
changeset = Bazaar.Schemas.Shopping.CheckoutResp.new(params)

# Create order params from checkout
order_params = Bazaar.Order.from_checkout(checkout, "order_123", "https://shop.com/orders/123")

# Currency helpers
cents = Bazaar.Checkout.to_minor_units(19.99)  # => 1999
dollars = Bazaar.Checkout.to_major_units(1999)  # => 19.99

# Message factories
error = Bazaar.Message.error(%{"code" => "out_of_stock", "content" => "Item unavailable"})
```

When the spec is updated, fetch the new version's schemas (needs `cargo install ucp-schema`) and regenerate:

```bash
mix run scripts/fetch_ucp_schemas.exs 2026-08-25
mix bazaar.gen.schemas priv/ucp_schemas/2026-08-25 \
  --roots "*.json,shopping/cart*.json,shopping/catalog*.json,shopping/checkout*.json,shopping/order*.json,shopping/fulfillment*.json,shopping/discount*.json,shopping/buyer_consent*.json,transports/*.json"
```

`--roots` keeps the generated modules to the capabilities bazaar exposes and what they reference; the validator still uses the full schema tree in `priv/`.

## Webhooks

Platforms learn about orders through webhooks: the full order document, POSTed to the URL the platform advertises in its profile, with `Webhook-Id` and `Webhook-Timestamp` headers and retries that keep both. Bazaar finds the URL and delivers the event; your handler decides when.

```elixir
def complete_checkout(id, conn) do
  # ... authorize payment, build the order ...
  {:ok, url} = Bazaar.Platform.webhook_url(conn.assigns.ucp_agent_profile, http_client: &MyApp.Http.get/1)
  event = Bazaar.Webhook.event(order, url)

  Task.Supervisor.start_child(MyApp.TaskSupervisor, fn ->
    Bazaar.Webhook.deliver(event, http_client: &MyApp.Http.post/3, signer: {key, "https://shop.example/.well-known/ucp"})
  end)

  {:ok, checkout}
end
```

Delivery is signed with RFC 9421 HTTP message signatures when you pass a `Bazaar.Signing.Key` (EC P-256 or Ed25519, loaded from PEM or JWK). Publish its public half as `"keys"` in `business_profile/0` and platforms verify against it. Bazaar bundles no HTTP client: the two functions above are yours, a few lines on Req or whatever you use.

## Plugs

Optional plugs for production use:

```elixir
pipeline :ucp do
  plug :accepts, ["json"]
  plug Bazaar.Plugs.UCP              # UCPHeaders (version negotiation) then Idempotency (replay)
  plug Bazaar.Plugs.VerifySignature, http_client: &MyApp.Http.get/1   # RFC 9421 request signatures, when present
  plug Bazaar.Plugs.ValidateRequest  # Validate request body
end
```

`VerifySignature` checks signed requests against the keys in the platform's profile and lets unsigned ones through unless `required: true`; it needs the raw body, so configure `Plug.Parsers` with `body_reader: {Bazaar.Plugs.RawBody, :read_body, []}`.

`Bazaar.Plugs.UCP` composes `Bazaar.Plugs.UCPHeaders` and `Bazaar.Plugs.Idempotency`; use them individually if you need something in between. Idempotency needs a store: `Bazaar.Idempotency.ETS` in your supervision tree for development and a single node, or `Bazaar.Idempotency.Cachex` on a [Cachex](https://hexdocs.pm/cachex) cache for production and any multi-node deployment. Errors from the plugs and the controller are spec-shaped: the UCP error response for UCP routes, the ACP `Error` object for ACP routes. See the [plugs guide](guides/plugs.md).

## Guides

- **[Getting Started](guides/getting-started.md)**: Build your first merchant
- **[Protocols](guides/protocols.md)**: Support both UCP and ACP
- **[Handlers](guides/handlers.md)**: Implement commerce logic
- **[Schemas](guides/schemas.md)**: Validate checkout and order data
- **[Plugs](guides/plugs.md)**: Add validation, idempotency, and headers
- **[Testing](guides/testing.md)**: Test your implementation

## Related Protocols

- [Agent2Agent (A2A)](https://developers.googleblog.com/en/a2a-a-new-era-of-agent-interoperability/): Agent communication
- [Model Context Protocol (MCP)](https://modelcontextprotocol.io/): AI model integration
- [Agent Payments Protocol (AP2)](https://developers.google.com/merchant/ucp): Secure payments

## License

Apache 2.0
