# Handlers Guide

Handlers are the core of your Ucphi implementation. They define what your store can do and how it responds to requests.

## Basic Structure

Every handler uses the `Ucphi.Handler` behaviour:

```elixir
defmodule MyApp.Commerce.Handler do
  use Ucphi.Handler

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

  case Ucphi.Schemas.CheckoutSession.new(params) do
    %{valid?: true} = changeset ->
      checkout = Ecto.Changeset.apply_changes(changeset)
      # Save to database...
      {:ok, checkout_to_map(checkout)}

    %{valid?: false} = changeset ->
      {:error, changeset}
  end
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
    checkout -> {:ok, checkout_to_map(checkout)}
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

    %{status: :complete} ->
      {:error, :invalid_state}

    checkout ->
      case update_checkout_record(checkout, params) do
        {:ok, updated} -> {:ok, checkout_to_map(updated)}
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

    %{status: :cancelled} ->
      {:error, :already_cancelled}

    checkout ->
      {:ok, _} = Repo.update(Checkout.cancel(checkout))
      {:ok, %{id: id, status: "cancelled"}}
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
    order -> {:ok, order_to_map(order)}
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

    %{status: :shipped} ->
      {:error, :invalid_state}

    %{status: :cancelled} ->
      {:error, :already_cancelled}

    order ->
      {:ok, _} = Repo.update(Order.cancel(order))
      {:ok, %{id: id, status: "cancelled"}}
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
          {:ok, %{linked: true, user_id: user_info.id}}

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

## Complete Example

```elixir
defmodule MyApp.Commerce.Handler do
  use Ucphi.Handler

  alias MyApp.{Repo, Checkout, Order}
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
    with %{valid?: true} = cs <- Ucphi.Schemas.CheckoutSession.new(params),
         data <- Ecto.Changeset.apply_changes(cs),
         {:ok, checkout} <- Repo.insert(Checkout.from_ucp(data)) do
      {:ok, Checkout.to_ucp(checkout)}
    else
      %{valid?: false} = changeset -> {:error, changeset}
      {:error, changeset} -> {:error, changeset}
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
    with checkout when not is_nil(checkout) <- Repo.get(Checkout, id),
         false <- checkout.status == :complete,
         {:ok, updated} <- Checkout.update(checkout, params) do
      {:ok, Checkout.to_ucp(updated)}
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
      %{status: :cancelled} -> {:error, :already_cancelled}
      checkout ->
        Repo.update!(Checkout.cancel(checkout))
        {:ok, %{id: id, status: "cancelled"}}
    end
  end

  # Orders

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
      nil -> {:error, :not_found}
      %{status: s} when s in [:shipped, :delivered] -> {:error, :invalid_state}
      order ->
        Repo.update!(Order.cancel(order))
        {:ok, %{id: id, status: "cancelled"}}
    end
  end

  # Webhooks

  @impl true
  def handle_webhook(%{"event" => "payment.completed"} = webhook) do
    Logger.info("Payment completed: #{inspect(webhook["data"])}")
    {:ok, :processed}
  end

  def handle_webhook(_), do: {:error, :unknown_event}
end
```

## Next Steps

- [Schemas Guide](schemas.md) - Learn about data validation
- [Plugs Guide](plugs.md) - Add middleware features
- [Testing Guide](testing.md) - Test your handler
