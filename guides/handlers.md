# Handlers Guide

Handlers are the core of your Bazaar implementation. They define what your store can do and how it responds to requests.

## Basic Structure

Every handler uses the `Bazaar.Handler` behaviour:

```elixir
defmodule MyApp.UCPHandler do
  use Bazaar.Handler

  @impl true
  def capabilities, do: [:checkout, :orders]

  @impl true
  def business_profile do
    %{
      "name" => "My Store",
      "description" => "We sell great stuff"
    }
  end

  # ... callback implementations
end
```

## Required Callbacks

### capabilities/0

Returns a list of capabilities your store supports:

```elixir
@impl true
def capabilities, do: [:checkout, :orders, :identity]
```

Available capabilities:
- `:checkout` - Shopping cart management
- `:orders` - Order tracking and management
- `:identity` - User identity linking (OAuth)

### business_profile/0

Returns your store's profile for the discovery endpoint:

```elixir
@impl true
def business_profile do
  %{
    "name" => "Cool Gadgets Store",
    "description" => "The best gadgets on the internet",
    "logo_url" => "https://example.com/logo.png",
    "website" => "https://example.com",
    "support_email" => "help@example.com"
  }
end
```

## Checkout Callbacks

If you include `:checkout` in capabilities, implement these:

### create_checkout/2

Called when an agent creates a new checkout session.

```elixir
@impl true
def create_checkout(params, conn) do
  # params: Map with checkout data (string keys)
  # conn: Plug.Conn (useful for auth info, headers)

  # Save to your database, then return full checkout response
  checkout = Repo.insert!(Checkout.from_params(params))

  {:ok, %{
    "id" => checkout.id,
    "status" => "incomplete",
    "currency" => params["currency"],
    "line_items" => enrich_line_items(params["line_items"]),
    "totals" => calculate_totals(params["line_items"]),
    "links" => [
      %{"type" => "privacy_policy", "url" => "https://mystore.example/privacy"},
      %{"type" => "terms_of_service", "url" => "https://mystore.example/terms"}
    ],
    "payment" => %{"handlers" => []}
  }}
end
```

**Parameters:**
- `params` - Map with string keys containing checkout data
- `conn` - The Plug connection (for accessing headers, auth, etc.)

**Returns:**
- `{:ok, map}` - Success with checkout data
- `{:error, changeset}` - Validation error
- `{:error, reason}` - Other error (atom or string)

### get_checkout/2

Fetches an existing checkout by ID.

```elixir
@impl true
def get_checkout(id, conn) do
  case Repo.get(Checkout, id) do
    nil -> {:error, :not_found}
    checkout -> {:ok, checkout_to_ucp(checkout)}
  end
end
```

**Returns:**
- `{:ok, map}` - Found checkout
- `{:error, :not_found}` - Checkout doesn't exist

### update_checkout/3

Updates an existing checkout.

```elixir
@impl true
def update_checkout(id, params, conn) do
  case Repo.get(Checkout, id) do
    nil ->
      {:error, :not_found}

    %{status: :completed} ->
      {:error, :invalid_state}

    checkout ->
      case update_checkout_record(checkout, params) do
        {:ok, updated} -> {:ok, checkout_to_ucp(updated)}
        {:error, changeset} -> {:error, changeset}
      end
  end
end
```

**Returns:**
- `{:ok, map}` - Updated checkout
- `{:error, :not_found}` - Checkout doesn't exist
- `{:error, :invalid_state}` - Can't update (e.g., already complete)
- `{:error, changeset}` - Validation error

### cancel_checkout/2

Cancels a checkout session.

```elixir
@impl true
def cancel_checkout(id, conn) do
  case Repo.get(Checkout, id) do
    nil ->
      {:error, :not_found}

    %{status: :canceled} ->
      {:error, :already_cancelled}

    checkout ->
      {:ok, _} = Repo.update(Checkout.cancel(checkout))
      {:ok, %{"id" => id, "status" => "canceled"}}
  end
end
```

## Order Callbacks

If you include `:orders` in capabilities, implement these:

### get_order/2

Fetches an order by ID.

```elixir
@impl true
def get_order(id, conn) do
  case Repo.get(Order, id) do
    nil -> {:error, :not_found}
    order -> {:ok, order_to_ucp(order)}
  end
end
```

### cancel_order/2

Cancels an order.

```elixir
@impl true
def cancel_order(id, conn) do
  case Repo.get(Order, id) do
    nil ->
      {:error, :not_found}

    %{fulfillment_status: :shipped} ->
      {:error, :invalid_state}

    %{status: :canceled} ->
      {:error, :already_cancelled}

    order ->
      {:ok, _} = Repo.update(Order.cancel(order))
      {:ok, %{"id" => id, "status" => "canceled"}}
  end
end
```

## Identity Callback

If you include `:identity` in capabilities:

### link_identity/2

Links a user identity via OAuth or other methods.

```elixir
@impl true
def link_identity(params, conn) do
  case params do
    %{"provider" => provider, "token" => token} ->
      case verify_oauth_token(provider, token) do
        {:ok, user_info} ->
          {:ok, %{"linked" => true, "user_id" => user_info.id}}

        {:error, reason} ->
          {:error, reason}
      end

    _ ->
      {:error, :invalid_params}
  end
end
```

## Webhook Callback

Handle incoming webhooks (optional):

### handle_webhook/1

```elixir
@impl true
def handle_webhook(%{"event" => "payment.completed", "data" => data}) do
  order_id = data["order_id"]
  # Update order status, send confirmation, etc.
  {:ok, :processed}
end

def handle_webhook(%{"event" => "payment.failed", "data" => data}) do
  order_id = data["order_id"]
  # Handle failed payment
  {:ok, :processed}
end

def handle_webhook(%{"event" => event}) do
  Logger.warning("Unknown webhook event: #{event}")
  {:error, :unknown_event}
end

def handle_webhook(_) do
  {:error, :invalid_webhook}
end
```

## Error Responses

The controller automatically formats errors. Use these return values:

| Return Value | HTTP Status | Description |
|--------------|-------------|-------------|
| `{:ok, map}` | 200/201 | Success |
| `{:error, :not_found}` | 404 | Resource not found |
| `{:error, changeset}` | 422 | Validation error |
| `{:error, :invalid_state}` | 422 | Invalid operation |
| `{:error, :unauthorized}` | 422 | Auth required |
| `{:error, :forbidden}` | 422 | Access denied |
| `{:error, "message"}` | 422 | Custom error |

## Using the Connection

The `conn` parameter gives you access to request info:

```elixir
def create_checkout(params, conn) do
  # Get UCP headers (if using UCPHeaders plug)
  agent = conn.assigns[:ucp_agent]
  request_id = conn.assigns[:ucp_request_id]

  # Get auth info (if using your auth plug)
  user = conn.assigns[:current_user]

  # Get raw headers
  auth_header = Plug.Conn.get_req_header(conn, "authorization")

  # ... rest of implementation
end
```

## UCP Response Format

### Checkout Response

Your handler must return checkouts in UCP format:

```elixir
%{
  "id" => "checkout_abc123",
  "status" => "incomplete",  # incomplete | requires_escalation | ready_for_complete | completed | canceled
  "currency" => "USD",
  "line_items" => [
    %{
      "item" => %{
        "id" => "PROD-1",
        "title" => "Widget",
        "price" => 1999  # cents
      },
      "quantity" => 2,
      "totals" => [
        %{"type" => "subtotal", "amount" => 3998}
      ]
    }
  ],
  "totals" => [
    %{"type" => "subtotal", "amount" => 3998},
    %{"type" => "tax", "amount" => 320},
    %{"type" => "total", "amount" => 4318}
  ],
  "links" => [
    %{"type" => "privacy_policy", "url" => "https://..."},
    %{"type" => "terms_of_service", "url" => "https://..."}
  ],
  "payment" => %{"handlers" => []}
}
```

### Order Response

```elixir
%{
  "id" => "order_xyz789",
  "checkout_id" => "checkout_abc123",
  "permalink_url" => "https://mystore.example/orders/xyz789",
  "line_items" => [...],
  "totals" => [...],
  "fulfillment" => %{
    "expectations" => [],
    "events" => []
  }
}
```

## Complete Example

```elixir
defmodule MyApp.UCPHandler do
  use Bazaar.Handler

  alias MyApp.{Repo, Checkout, Order, Product}
  require Logger

  @impl true
  def capabilities, do: [:checkout, :orders]

  @impl true
  def business_profile do
    %{
      "name" => Application.get_env(:my_app, :store_name),
      "description" => "Your one-stop shop",
      "support_email" => "support@example.com"
    }
  end

  # Checkout

  @impl true
  def create_checkout(params, _conn) do
    line_items = enrich_line_items(params["line_items"])
    totals = calculate_totals(line_items)

    checkout = %Checkout{
      id: generate_id("checkout"),
      currency: params["currency"],
      line_items: line_items,
      totals: totals,
      status: :incomplete
    }

    case Repo.insert(checkout) do
      {:ok, saved} -> {:ok, to_ucp(saved)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def get_checkout(id, _conn) do
    case Repo.get(Checkout, id) do
      nil -> {:error, :not_found}
      checkout -> {:ok, to_ucp(checkout)}
    end
  end

  @impl true
  def update_checkout(id, params, _conn) do
    with checkout when not is_nil(checkout) <- Repo.get(Checkout, id),
         false <- checkout.status == :completed,
         {:ok, updated} <- Checkout.update(checkout, params) do
      {:ok, to_ucp(updated)}
    else
      nil -> {:error, :not_found}
      true -> {:error, :invalid_state}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def cancel_checkout(id, _conn) do
    case Repo.get(Checkout, id) do
      nil -> {:error, :not_found}
      %{status: :canceled} -> {:error, :already_cancelled}
      checkout ->
        Repo.update!(Checkout.cancel(checkout))
        {:ok, %{"id" => id, "status" => "canceled"}}
    end
  end

  # Orders

  @impl true
  def get_order(id, _conn) do
    case Repo.get(Order, id) do
      nil -> {:error, :not_found}
      order -> {:ok, order_to_ucp(order)}
    end
  end

  @impl true
  def cancel_order(id, _conn) do
    case Repo.get(Order, id) do
      nil -> {:error, :not_found}
      %{status: s} when s in [:shipped, :delivered] -> {:error, :invalid_state}
      order ->
        Repo.update!(Order.cancel(order))
        {:ok, %{"id" => id, "status" => "canceled"}}
    end
  end

  # Webhooks

  @impl true
  def handle_webhook(%{"event" => "payment.completed"} = webhook) do
    Logger.info("Payment completed: #{inspect(webhook["data"])}")
    {:ok, :processed}
  end

  def handle_webhook(_), do: {:error, :unknown_event}

  # Private helpers

  defp enrich_line_items(line_items) do
    Enum.map(line_items, fn li ->
      product = Repo.get!(Product, li["item"]["id"])
      %{
        "item" => %{
          "id" => product.id,
          "title" => product.title,
          "price" => product.price_cents
        },
        "quantity" => li["quantity"],
        "totals" => [
          %{"type" => "subtotal", "amount" => product.price_cents * li["quantity"]}
        ]
      }
    end)
  end

  defp calculate_totals(line_items) do
    subtotal = Enum.reduce(line_items, 0, fn li, acc ->
      acc + hd(li["totals"])["amount"]
    end)

    tax = round(subtotal * 0.08)  # 8% tax

    [
      %{"type" => "subtotal", "amount" => subtotal},
      %{"type" => "tax", "amount" => tax},
      %{"type" => "total", "amount" => subtotal + tax}
    ]
  end

  defp to_ucp(checkout) do
    %{
      "id" => checkout.id,
      "status" => to_string(checkout.status),
      "currency" => checkout.currency,
      "line_items" => checkout.line_items,
      "totals" => checkout.totals,
      "links" => [
        %{"type" => "privacy_policy", "url" => "https://mystore.example/privacy"},
        %{"type" => "terms_of_service", "url" => "https://mystore.example/terms"}
      ],
      "payment" => %{"handlers" => []}
    }
  end

  defp order_to_ucp(order) do
    %{
      "id" => order.id,
      "checkout_id" => order.checkout_id,
      "permalink_url" => "https://mystore.example/orders/#{order.id}",
      "line_items" => order.line_items,
      "totals" => order.totals,
      "fulfillment" => %{
        "expectations" => order.fulfillment_expectations || [],
        "events" => order.fulfillment_events || []
      }
    }
  end

  defp generate_id(prefix), do: "#{prefix}_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
end
```

## Next Steps

- [Schemas Guide](schemas.md) - Learn about data validation
- [Plugs Guide](plugs.md) - Add middleware features
- [Testing Guide](testing.md) - Test your handler
