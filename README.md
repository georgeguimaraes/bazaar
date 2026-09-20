# Bazaar

**Open your store to AI agents.** Elixir SDK for the [Universal Commerce Protocol](https://ucp.dev).

Bazaar helps you build commerce APIs in Elixir/Phoenix that Google Shopping agents can discover, browse and buy from.

> [!TIP]
> [examples/flower_shop](https://github.com/georgeguimaraes/bazaar/tree/main/examples/flower_shop) is a runnable merchant that passes the official UCP conformance suite, and CI runs that suite against it on every push.

## The Protocol

UCP lets AI agents discover what your store offers, search your catalog, build carts, complete checkouts and track orders. It was announced by Google at NRF 2026, co-developed with Shopify, Walmart, Etsy and Target. Bazaar implements the `2026-08-25` version over REST.

Support for [ACP](https://github.com/agentic-commerce-protocol/agentic-commerce-protocol), the OpenAI and Stripe protocol, is in progress and not documented here yet.

## Features

- **Every Capability**: Checkout, orders, carts, catalog, locations, fulfillment including pickup, discounts, loyalty, payment terms, buyer consent
- **Shop, Store and Handler**: your facts, your persistence, every UCP callback by default
- **Phoenix Router Macro**: Mount every route with one line, behind one plug
- **One Plug**: Version negotiation, idempotent replay, inbound signature verification and response signing
- **Auto-generated Discovery**: `/.well-known/ucp` from your handler's capabilities
- **Signed Webhooks**: Order events delivered, signed and retried, with no code of yours
- **Generated Schemas**: Smelter-generated Ecto schemas and JSON Schema validation from the official UCP schemas
- **Checkout Document Builder**: `Bazaar.Checkout` merges updates with the spec's carry-over rules and builds the document (totals, fulfillment, discounts, status) from your prices, stock and rates
- **Business Logic Helpers**: Currency conversion, message factories, order creation, catalog filters and pagination

## How It Works

Bazaar handles the protocol. You write the commerce logic.

```
Agent request → Bazaar's plug and router → your shop's facts → a spec-shaped response
```

| Bazaar | You |
|--------|-----|
| Routes and validates what agents send | Price items and check stock |
| Builds every document the spec defines | Quote shipping and pickup |
| Negotiates versions, replays idempotent requests | Charge the payment instruments |
| Verifies and signs HTTP message signatures | Query your database |
| Delivers and retries order webhooks | Decide what a discount code is worth |

## Architecture

```
lib/bazaar/
├── schemas/
│   ├── ucp/           # Generated UCP schemas (from Smelter)
│   │   ├── shopping/  # Checkout, Order, Payment types
│   │   ├── capability/# Capability definitions
│   │   └── ucp/       # Discovery profile, response types
│   └── acp/           # ACP schemas (in progress)
├── validator.ex       # Schema validation against the bundled JSON Schemas (via JSV)
├── checkout.ex        # Checkout state, update rules and document builder
├── order.ex           # Order documents: from a checkout, platform updates, fulfillment events
├── message.ex         # Business logic: error/warning/info factories
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

### Step 1: Generate a Handler

```bash
mix bazaar.gen.handler MyApp.CommerceHandler --name "My Awesome Store"
```

This writes a handler and a `Bazaar.Shop` with placeholder data (a sample product, one flat rate) so the store answers on first boot, and prints the endpoint, router and supervision wiring below. The [getting started guide](guides/getting-started.md) walks through it. A store is three modules:

```elixir
defmodule MyApp.CommerceHandler do
  use Bazaar.Handler, shop: MyApp.Shop, store: Bazaar.Store.ETS

  @impl true
  def capabilities, do: [:checkout, :orders, :fulfillment]

  @impl true
  def business_profile, do: %{"name" => "My Awesome Store"}
end

defmodule MyApp.Shop do
  use Bazaar.Shop

  @impl true
  def base_url, do: "https://shop.example"

  @impl true
  def item(id), do: MyApp.Products.item(id)   # %{item: %{"title", "price"}, stock: n} | nil

  @impl true
  def fulfillment_options(destination, context), do: MyApp.Shipping.options(destination, context)
end
```

Every UCP callback (checkout, carts, orders, catalog, locations) is defined by default from the shop and the store, and any of them can be overridden. `Bazaar.Store.ETS` keeps state in memory; `Bazaar.Store.Ecto` (with the migration from `mix bazaar.gen.store`) keeps it in your database.

### Step 2: Mount Routes

Add the routes to your Phoenix router:

```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router
  use Bazaar.Phoenix.Router

  pipeline :ucp do
    plug :accepts, ["json"]
    plug Bazaar.Plugs.UCP   # versions, idempotent replay, request and response signatures
  end

  scope "/" do
    pipe_through :ucp
    bazaar_routes "/", MyApp.CommerceHandler
  end
end
```

Nothing goes in your supervision tree: the in-memory stores start themselves on first use. The shop needs its base URL in config, and the endpoint has to keep the raw body for signature checks (the generator prints both):

```elixir
# config/runtime.exs
config :my_app, bazaar_base_url: System.get_env("BASE_URL", "http://localhost:4000")

# lib/my_app_web/endpoint.ex
plug Plug.Parsers,
  parsers: [:json], pass: ["*/*"], json_decoder: Jason,
  body_reader: {Bazaar.Plugs.RawBody, :read_body, []}
```

Endpoints:

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
| POST | `/locations/search` | Search stores (with `:location`) |
| POST | `/locations/lookup` | Look up stores by id (with `:location`) |
| POST | `/catalog/search` | Search products (with `:catalog`) |
| POST | `/catalog/lookup` | Look up products by id (with `:catalog`) |
| POST | `/catalog/product` | Get one product (with `:catalog`) |
| POST | `/webhooks/ucp` | Receive webhooks |

`bazaar_routes` is a convenience, not a requirement. If you'd rather own the routes and controllers, skip it: build the discovery document with `Bazaar.DiscoveryProfile.from_handler(MyApp.CommerceHandler, base_url: url)`, call the handler callbacks from your own actions, and keep using the plugs and helpers. You can also mix the two, which is what [examples/flower_shop](https://github.com/georgeguimaraes/bazaar/tree/main/examples/flower_shop) does: `bazaar_routes` for the standard routes and a few hand-written ones for what the conformance suite needs beyond the spec.

### Step 3: Test It

```bash
# Discovery
curl http://localhost:4000/.well-known/ucp

# Create a checkout (the generated shop ships a "sample" product)
curl -X POST http://localhost:4000/checkout-sessions \
  -H "Content-Type: application/json" \
  -d '{"currency":"USD","line_items":[{"item":{"id":"sample"},"quantity":2}]}'
```

## Validation

Bazaar bundles schema validation for both protocols:

```elixir
Bazaar.Validator.validate(data, :checkout)
Bazaar.Validator.validate(data, :cart)
Bazaar.Validator.validate(data, :order)
Bazaar.Validator.validate(data, :profile)
Bazaar.Validator.validate(data, :catalog_search_response)
Bazaar.Validator.validate(data, :catalog_lookup_response)
Bazaar.Validator.validate(data, :catalog_product_response)
Bazaar.Validator.validate(data, :location_search_response)
Bazaar.Validator.validate(data, :location_lookup_response)
Bazaar.Validator.validate(data, :checkout_loyalty)
Bazaar.Validator.validate(data, :checkout_payment_terms)

# Every schema name
Bazaar.Validator.available_schemas()
```

The bundled schemas track the [UCP spec](https://ucp.dev), currently `2026-08-25`. `mix bazaar.gen.handler` wires `Bazaar.Plugs.ValidateResponse, strict: true` in dev and test so every response is checked as you build.

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
| `:loyalty` | Loyalty memberships on checkouts, carts and the catalog | `Bazaar.Checkout.build/2`'s `:loyalty` option, `eligibility/1` for the platform's claims |
| `:payment_terms` | Selectable payment terms on checkouts, carried onto orders | `Bazaar.Checkout.build/2`'s `:payment_terms` option |
| `:location` | Store discovery | `search_locations`, `lookup_locations` (see `Bazaar.Location` for distance, hours, amenities and lookup rules) |

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
  --roots "*.json,shopping/cart*.json,shopping/catalog*.json,shopping/checkout*.json,shopping/order*.json,shopping/fulfillment*.json,shopping/discount*.json,shopping/buyer_consent*.json"
```

`--roots` keeps the generated modules to the capabilities bazaar exposes and what they reference; the validator still uses the full schema tree in `priv/`.

The task ships with the library and so do the schemas, so you can generate from them yourself: the transport envelopes bazaar leaves out (MCP, A2A, embedded), a capability it doesn't serve, or your own JSON Schemas.

```bash
mix bazaar.gen.schemas deps/bazaar/priv/ucp_schemas/2026-08-25 \
  --roots "transports/*.json" --output-dir lib/my_app/schemas --prefix MyApp.Schemas
```

## Webhooks

Platforms learn about orders through webhooks: the full order document, POSTed to the URL the platform advertises in its profile, signed, with `Webhook-Id` and `Webhook-Timestamp` headers and retries that keep both. Bazaar does all of it once your shop names an HTTP client and a signing key:

```elixir
defmodule MyApp.Shop do
  use Bazaar.Shop

  @impl true
  def http_client, do: %{get: &MyApp.Http.get/1, post: &MyApp.Http.post/3}

  @impl true
  def signing_key, do: MyApp.Signing.key()
end
```

Every order placed or changed is then delivered off the request path with RFC 9421 signatures, verified by platforms against the public key you publish as `"keys"` in `business_profile/0`. Override `order_placed/2` or `order_updated/2` to do it yourself. Bazaar bundles no HTTP client: those two functions are yours, a few lines on Req or whatever you use.

## Plugs

Optional plugs for production use:

```elixir
pipeline :ucp do
  plug :accepts, ["json"]
  plug Bazaar.Plugs.UCP              # versions, idempotent replay, request and response signatures
  plug Bazaar.Plugs.ValidateRequest  # optional, validate request bodies
end
```

`Bazaar.Plugs.UCP` is the whole request path: version negotiation, idempotent replay, signature verification against the platform's published keys, and signing the answer with your shop's key. The four steps are public plugs too, for a pipeline that needs its own order.

`Bazaar.Plugs.UCP` composes `UCPHeaders`, `Idempotency`, `VerifySignature` and `SignResponse`; use them individually if you need something in between. Idempotency keeps its records in memory by default, started on first use, which suits development and a single node; pass `store: {Bazaar.Idempotency.Cachex, :cache}` on a [Cachex](https://hexdocs.pm/cachex) cache for production and any multi-node deployment. Errors from the plugs and the controller are spec-shaped, with `ucp.status: "error"` and typed `messages[]`. See the [plugs guide](guides/plugs.md).

## Guides

- **[Getting Started](guides/getting-started.md)**: Build your first merchant
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
