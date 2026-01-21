# Bazaar 🎪

**Open your store to AI agents.** Elixir SDK for [UCP](https://ucp.dev) and [ACP](https://github.com/agentic-commerce-protocol/acp-spec).

Bazaar helps you build commerce APIs in Elixir/Phoenix that work with both Google Shopping agents (UCP) and OpenAI/Stripe agents (ACP) from a single handler.

> [!TIP]
> See [bazaar-merchant](https://github.com/georgeguimaraes/bazaar-merchant) for a complete Phoenix app demonstrating a dual-protocol merchant.

## Supported Protocols

| Protocol | Used By | Spec |
|----------|---------|------|
| **UCP** (Universal Commerce Protocol) | Google Shopping agents | [ucp.dev](https://ucp.dev) |
| **ACP** (Agentic Commerce Protocol) | OpenAI Operator, Stripe | [GitHub](https://github.com/agentic-commerce-protocol/acp-spec) |

Both protocols enable AI agents to:

- Discover what your store offers
- Create and manage shopping carts
- Complete checkouts
- Track orders

UCP was announced by Google at NRF 2026, co-developed with Shopify, Walmart, Etsy, and Target. ACP is backed by OpenAI and Stripe.

## Features

- **Generated Schemas**: Smelter-generated Ecto schemas from official UCP JSON Schemas
- **Phoenix Router Macro**: Mount all UCP routes with a single line
- **Handler Behaviour**: Clean interface for your commerce logic
- **Built-in Plugs**: Request validation, idempotency, and UCP headers
- **Auto-generated Discovery**: `/.well-known/ucp` endpoint from your handler
- **Business Logic Helpers**: Currency conversion, message factories, order creation

## Architecture

Bazaar separates concerns cleanly:

```
lib/bazaar/
├── schemas/           # Generated from UCP JSON Schemas (via Smelter)
│   ├── shopping/      # Checkout, Order, Payment types
│   ├── capability/    # Capability definitions
│   └── ucp/           # Discovery profile, response types
├── checkout.ex        # Business logic: currency helpers
├── order.ex           # Business logic: from_checkout helper
├── message.ex         # Business logic: error/warning/info factories
├── fulfillment.ex     # Business logic: field definitions
├── handler.ex         # Handler behaviour
├── phoenix/           # Router and controller
└── plugs/             # Request validation, headers, idempotency
```

**Schemas** are generated from JSON and provide validation via `new/1` and `fields/0`.
**Business logic** modules add helpers and factories on top of the schemas.

## How It Works

Bazaar is a thin layer that connects your Phoenix app to AI shopping agents via UCP.

```
AI Agent → UCP Request → Bazaar Router → Bazaar Controller → Your Handler → Response
```

Bazaar handles the HTTP/JSON plumbing. You write the commerce logic.

| Bazaar | You |
|--------|-----|
| Parses JSON, validates structure | Write business logic |
| Routes to correct callback | Query your database |
| Handles UCP headers | Calculate prices, tax, shipping |
| Returns proper HTTP responses | Integrate with payment/fulfillment |

Bazaar doesn't touch your database or know about your products. It just speaks UCP so AI agents can shop at your store.

## Installation

Add `bazaar` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bazaar, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Quick Start

### Step 1: Create a Handler

The handler defines your store's capabilities and commerce logic:

```elixir
defmodule MyApp.UCPHandler do
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
    # Save to your DB, return the checkout map
    {:ok, %{"id" => "chk_123", "status" => "incomplete", ...}}
  end

  @impl true
  def get_checkout(id, _conn) do
    # Fetch from your DB
    {:ok, checkout} or {:error, :not_found}
  end

  # ... other callbacks: update_checkout, cancel_checkout, get_order, cancel_order
end
```

### Step 2: Mount Routes

Add UCP routes to your Phoenix router:

```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router
  use Bazaar.Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/" do
    pipe_through :api
    bazaar_routes "/", MyApp.UCPHandler
  end
end
```

This creates these endpoints:

| Method | Path | Description |
|--------|------|-------------|
| GET | `/.well-known/ucp` | Discovery endpoint |
| POST | `/checkout-sessions` | Create checkout |
| GET | `/checkout-sessions/:id` | Get checkout |
| PATCH | `/checkout-sessions/:id` | Update checkout |
| DELETE | `/checkout-sessions/:id` | Cancel checkout |
| GET | `/orders/:id` | Get order |
| POST | `/orders/:id/actions/cancel` | Cancel order |
| POST | `/webhooks/ucp` | Receive webhooks |

### Step 3: Test It

Start your server and test the discovery endpoint:

```bash
curl http://localhost:4000/.well-known/ucp
```

You should see your store's profile and capabilities.

## Guides

New to Bazaar? Check out these guides:

- **[Getting Started](guides/getting-started.md)** - Build your first UCP merchant
- **[Protocols](guides/protocols.md)** - Support both UCP and ACP
- **[Handlers](guides/handlers.md)** - Implement commerce logic
- **[Schemas](guides/schemas.md)** - Validate checkout and order data
- **[Plugs](guides/plugs.md)** - Add validation, idempotency, and headers
- **[Testing](guides/testing.md)** - Test your implementation

## Core Concepts

### Capabilities

UCP defines three capabilities your store can support:

| Capability | Description | Callbacks |
|------------|-------------|-----------|
| `:checkout` | Shopping cart management | `create_checkout`, `get_checkout`, `update_checkout`, `cancel_checkout` |
| `:orders` | Order tracking | `get_order`, `cancel_order` |
| `:identity` | User identity linking | `link_identity` |

### Schemas

Bazaar schemas are generated from official UCP JSON Schemas using [Smelter](https://github.com/georgeguimaraes/smelter):

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

### Regenerating Schemas

If UCP schemas are updated, regenerate with:

```bash
mix bazaar.gen.schemas priv/ucp_schemas/2026-01-11
```

### Plugs

Optional plugs for production use:

```elixir
pipeline :ucp do
  plug Bazaar.Plugs.UCPHeaders      # Extract UCP headers
  plug Bazaar.Plugs.ValidateRequest  # Validate request body
  plug Bazaar.Plugs.Idempotency      # Handle retry safety
end
```

## Example: Complete Handler

Here's a more complete handler example:

```elixir
defmodule MyApp.Commerce.Handler do
  use Bazaar.Handler

  alias MyApp.{Repo, Checkout, Order}

  @impl true
  def capabilities, do: [:checkout, :orders]

  @impl true
  def business_profile do
    %{
      "name" => "Cool Gadgets Store",
      "description" => "The best gadgets on the internet",
      "support_email" => "help@coolgadgets.example"
    }
  end

  # Checkout callbacks

  @impl true
  def create_checkout(params, _conn) do
    case Bazaar.Schemas.Shopping.CheckoutResp.new(params) do
      %{valid?: true} = changeset ->
        data = Ecto.Changeset.apply_changes(changeset)
        checkout = Repo.insert!(Checkout.from_ucp(data))
        {:ok, Checkout.to_ucp(checkout)}

      %{valid?: false} = changeset ->
        {:error, changeset}
    end
  end

  @impl true
  def get_checkout(id, _conn) do
    case Repo.get(Checkout, id) do
      nil -> {:error, :not_found}
      checkout -> {:ok, Checkout.to_ucp(checkout)}
    end
  end

  @impl true
  def update_checkout(id, params, _conn) do
    case Repo.get(Checkout, id) do
      nil ->
        {:error, :not_found}

      checkout ->
        checkout
        |> Checkout.changeset(params)
        |> Repo.update()
        |> case do
          {:ok, updated} -> {:ok, Checkout.to_ucp(updated)}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @impl true
  def cancel_checkout(id, _conn) do
    case Repo.get(Checkout, id) do
      nil -> {:error, :not_found}
      checkout ->
        {:ok, _} = Repo.update(Checkout.cancel(checkout))
        {:ok, %{id: id, status: "cancelled"}}
    end
  end

  # Order callbacks

  @impl true
  def get_order(id, _conn) do
    case Repo.get(Order, id) do
      nil -> {:error, :not_found}
      order -> {:ok, Order.to_ucp(order)}
    end
  end

  @impl true
  def cancel_order(id, _conn) do
    case Repo.get(Order, id) do
      nil ->
        {:error, :not_found}

      %{status: :shipped} ->
        {:error, :invalid_state}

      order ->
        {:ok, _} = Repo.update(Order.cancel(order))
        {:ok, %{id: id, status: "cancelled"}}
    end
  end

  # Webhook callback

  @impl true
  def handle_webhook(%{"event" => "payment.completed", "data" => data}) do
    # Handle payment completion
    {:ok, :processed}
  end

  def handle_webhook(_), do: {:error, :unknown_event}
end
```

## ACP (Agentic Commerce Protocol) Support

Bazaar also supports [ACP](https://github.com/agentic-commerce-protocol/acp-spec), the commerce protocol used by OpenAI's Operator and Stripe. You can serve both UCP and ACP clients from the same handler.

### Internal Format: UCP

Bazaar uses UCP as its internal/canonical format. Your handler always works with UCP field names and status values, regardless of which protocol the client uses:

```
ACP Request → [transform to UCP] → Your Handler → [transform to ACP] → ACP Response
UCP Request → Your Handler → UCP Response
```

This means you write your handler once using UCP conventions (`items`, `street_address`, `incomplete`), and Bazaar automatically translates for ACP clients (`line_items`, `line_one`, `not_ready_for_payment`).

### Dual Protocol Setup

Mount both protocols at different paths:

```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router
  use Bazaar.Phoenix.Router

  scope "/" do
    pipe_through :api

    # UCP routes (Google agents)
    bazaar_routes "/", MyApp.UCPHandler

    # ACP routes (OpenAI/Stripe agents)
    bazaar_routes "/acp", MyApp.UCPHandler, protocol: :acp
  end
end
```

### Protocol Differences

Bazaar automatically handles the differences between UCP and ACP:

| Aspect | UCP | ACP |
|--------|-----|-----|
| URL style | `/checkout-sessions` | `/checkout_sessions` |
| Update method | `PATCH` | `POST` |
| Cancel method | `DELETE` | `POST /cancel` |
| Discovery | `/.well-known/ucp` | None |
| Status: incomplete | `incomplete` | `not_ready_for_payment` |
| Status: ready | `ready_for_complete` | `ready_for_payment` |
| Address: street | `street_address` | `line_one` |
| Address: city | `address_locality` | `city` |
| Items key | `items` | `line_items` |

Your handler code stays the same: Bazaar transforms requests and responses automatically.

### ACP Routes

When using `protocol: :acp`, these endpoints are created:

| Method | Path | Description |
|--------|------|-------------|
| POST | `/checkout_sessions` | Create checkout |
| GET | `/checkout_sessions/:id` | Get checkout |
| POST | `/checkout_sessions/:id` | Update checkout |
| POST | `/checkout_sessions/:id/complete` | Complete checkout |
| POST | `/checkout_sessions/:id/cancel` | Cancel checkout |

## Related Protocols

UCP integrates with:

- [Agent2Agent (A2A)](https://developers.googleblog.com/en/a2a-a-new-era-of-agent-interoperability/) - Agent communication
- [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) - AI model integration
- [Agent Payments Protocol (AP2)](https://developers.google.com/merchant/ucp) - Secure payments

## License

Apache 2.0
