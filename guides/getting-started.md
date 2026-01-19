# Getting Started with Bazaar

This guide walks you through building your first UCP-compliant merchant API with Bazaar.

## Prerequisites

- Elixir 1.14 or later
- Phoenix 1.7 or later (for the router integration)
- Basic familiarity with Elixir and Phoenix

## What We're Building

By the end of this guide, you'll have a working API that:

1. Exposes a discovery endpoint for AI agents
2. Accepts checkout session creation requests
3. Returns validated responses

## Step 1: Create a New Phoenix Project

If you don't have an existing project, create one:

```bash
mix phx.new my_store --no-html --no-assets --no-mailer
cd my_store
```

## Step 2: Add Bazaar

Add bazaar to your dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:phoenix, "~> 1.7"},
    # ... other deps
    {:bazaar, "~> 0.1.0"}
  ]
end
```

Fetch dependencies:

```bash
mix deps.get
```

## Step 3: Create Your Handler

Create a new file at `lib/my_store/commerce/handler.ex`:

```elixir
defmodule MyStore.Commerce.Handler do
  use Bazaar.Handler

  @impl true
  def capabilities, do: [:checkout]

  @impl true
  def business_profile do
    %{
      "name" => "My Store",
      "description" => "A demo store built with Bazaar"
    }
  end

  @impl true
  def create_checkout(params, _conn) do
    case Bazaar.Schemas.CheckoutSession.new(params) do
      %{valid?: true} = changeset ->
        checkout = Ecto.Changeset.apply_changes(changeset)

        # In a real app, you'd save this to a database
        # For now, we'll just add an ID and return it
        checkout_map =
          checkout
          |> Map.from_struct()
          |> Map.put(:id, "checkout_#{System.unique_integer([:positive])}")

        {:ok, checkout_map}

      %{valid?: false} = changeset ->
        {:error, changeset}
    end
  end

  @impl true
  def get_checkout(_id, _conn) do
    # In a real app, you'd fetch from database
    {:error, :not_found}
  end

  @impl true
  def update_checkout(_id, _params, _conn) do
    {:error, :not_found}
  end

  @impl true
  def cancel_checkout(_id, _conn) do
    {:error, :not_found}
  end
end
```

## Step 4: Mount the Routes

Update your router at `lib/my_store_web/router.ex`:

```elixir
defmodule MyStoreWeb.Router do
  use MyStoreWeb, :router
  use Bazaar.Phoenix.Router  # Add this line

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Add this scope
  scope "/", MyStoreWeb do
    pipe_through :api
    bazaar_routes "/", MyStore.Commerce.Handler
  end
end
```

## Step 5: Start the Server

```bash
mix phx.server
```

## Step 6: Test Your API

### Test the Discovery Endpoint

```bash
curl http://localhost:4000/.well-known/ucp | jq
```

You should see:

```json
{
  "name": "My Store",
  "description": "A demo store built with Bazaar",
  "capabilities": [
    {
      "name": "checkout",
      "version": "1.0",
      "endpoint": "/checkout-sessions"
    }
  ],
  "transports": [
    {
      "type": "rest",
      "endpoint": "http://localhost:4000",
      "version": "1.0"
    }
  ]
}
```

### Create a Checkout Session

```bash
curl -X POST http://localhost:4000/checkout-sessions \
  -H "Content-Type: application/json" \
  -d '{
    "currency": "USD",
    "line_items": [
      {
        "sku": "WIDGET-001",
        "name": "Amazing Widget",
        "quantity": 2,
        "unit_price": "29.99"
      }
    ]
  }' | jq
```

You should see a response with the checkout data and a generated ID.

### Test Validation

Try creating a checkout with invalid data:

```bash
curl -X POST http://localhost:4000/checkout-sessions \
  -H "Content-Type: application/json" \
  -d '{
    "currency": "INVALID"
  }' | jq
```

You should see a validation error response:

```json
{
  "error": "validation_error",
  "message": "Validation failed",
  "details": [
    {"field": "currency", "message": "is invalid"},
    {"field": "line_items", "message": "can't be blank"}
  ]
}
```

## What's Next?

Now that you have a basic UCP merchant running:

1. **Add persistence**: Store checkouts in a database
2. **Add orders**: Implement the `:orders` capability
3. **Add plugs**: Use validation and idempotency plugs
4. **Handle webhooks**: Process payment notifications

Check out these guides:

- [Handlers Guide](handlers.md) - Learn all handler callbacks
- [Schemas Guide](schemas.md) - Understand data validation
- [Plugs Guide](plugs.md) - Add production-ready features
- [Testing Guide](testing.md) - Test your implementation

## Common Issues

### "module Bazaar.Phoenix.Router is not available"

Make sure you've added bazaar to your deps and run `mix deps.get`.

### Routes not showing up

Check that you:
1. Added `use Bazaar.Phoenix.Router` to your router
2. Called `bazaar_routes/2` inside a scope with `pipe_through :api`

### Validation errors for valid data

Make sure your params use string keys, not atom keys:

```elixir
# Correct
%{"currency" => "USD"}

# Wrong
%{currency: "USD"}
```
