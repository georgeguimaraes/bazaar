# Testing Guide

This guide shows you how to test your Bazaar implementation.

## Testing Handlers

### Basic Handler Test

```elixir
defmodule MyApp.Commerce.HandlerTest do
  use ExUnit.Case, async: true

  alias MyApp.Commerce.Handler

  describe "capabilities/0" do
    test "returns expected capabilities" do
      assert Handler.capabilities() == [:checkout, :orders]
    end
  end

  describe "business_profile/0" do
    test "returns store profile" do
      profile = Handler.business_profile()

      assert profile["name"] == "My Store"
      assert is_binary(profile["description"])
    end
  end

  describe "create_checkout/2" do
    test "creates checkout with valid params" do
      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"sku" => "TEST-1", "quantity" => 1, "unit_price" => "19.99"}
        ]
      }

      assert {:ok, checkout} = Handler.create_checkout(params, nil)
      assert checkout.currency == "USD"
    end

    test "returns error for invalid params" do
      params = %{"currency" => "INVALID"}

      assert {:error, changeset} = Handler.create_checkout(params, nil)
      refute changeset.valid?
    end
  end

  describe "get_checkout/2" do
    test "returns checkout when found" do
      # Setup: create a checkout first
      {:ok, created} = Handler.create_checkout(valid_params(), nil)

      assert {:ok, checkout} = Handler.get_checkout(created.id, nil)
      assert checkout.id == created.id
    end

    test "returns not_found for missing checkout" do
      assert {:error, :not_found} = Handler.get_checkout("nonexistent", nil)
    end
  end

  defp valid_params do
    %{
      "currency" => "USD",
      "line_items" => [
        %{"sku" => "TEST-1", "quantity" => 1, "unit_price" => "10.00"}
      ]
    }
  end
end
```

### Testing with Database

```elixir
defmodule MyApp.Commerce.HandlerTest do
  use MyApp.DataCase, async: true

  alias MyApp.Commerce.Handler
  alias MyApp.Repo

  setup do
    # Clean up before each test
    :ok
  end

  describe "create_checkout/2" do
    test "persists checkout to database" do
      params = valid_checkout_params()

      {:ok, checkout} = Handler.create_checkout(params, nil)

      # Verify it's in the database
      assert Repo.get!(MyApp.Checkout, checkout.id)
    end
  end

  describe "cancel_checkout/2" do
    test "updates status to cancelled" do
      {:ok, checkout} = Handler.create_checkout(valid_checkout_params(), nil)

      {:ok, cancelled} = Handler.cancel_checkout(checkout.id, nil)

      assert cancelled.status == "cancelled"

      # Verify in database
      db_checkout = Repo.get!(MyApp.Checkout, checkout.id)
      assert db_checkout.status == :cancelled
    end
  end
end
```

## Testing Schemas

### CheckoutSession Tests

```elixir
defmodule Bazaar.Schemas.CheckoutSessionTest do
  use ExUnit.Case, async: true

  alias Bazaar.Schemas.CheckoutSession

  describe "new/1" do
    test "creates valid changeset with required fields" do
      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"sku" => "ABC", "quantity" => 1, "unit_price" => "10.00"}
        ]
      }

      changeset = CheckoutSession.new(params)

      assert changeset.valid?
    end

    test "requires currency" do
      params = %{
        "line_items" => [
          %{"sku" => "ABC", "quantity" => 1, "unit_price" => "10.00"}
        ]
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).currency
    end

    test "validates currency format" do
      params = %{
        "currency" => "INVALID",
        "line_items" => [%{"sku" => "ABC", "quantity" => 1, "unit_price" => "10.00"}]
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).currency
    end

    test "requires at least one line item" do
      params = %{"currency" => "USD", "line_items" => []}

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
    end

    test "validates line item quantity > 0" do
      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"sku" => "ABC", "quantity" => 0, "unit_price" => "10.00"}
        ]
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
    end
  end

  # Helper to extract errors
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
```

### Order Tests

```elixir
defmodule Bazaar.Schemas.OrderTest do
  use ExUnit.Case, async: true

  alias Bazaar.Schemas.Order

  describe "from_checkout/2" do
    test "creates order from checkout data" do
      checkout = %{
        id: "checkout_123",
        currency: "USD",
        total: Decimal.new("99.99"),
        line_items: [%{sku: "ABC", quantity: 1, unit_price: Decimal.new("99.99")}],
        buyer: %{email: "test@example.com"},
        shipping_address: %{city: "NYC", country: "US"}
      }

      changeset = Order.from_checkout(checkout, "order_456")

      assert changeset.valid?

      order = Ecto.Changeset.apply_changes(changeset)
      assert order.id == "order_456"
      assert order.checkout_session_id == "checkout_123"
      assert order.status == :pending
    end
  end
end
```

## Testing Routes

### Using Phoenix.ConnTest

```elixir
defmodule MyAppWeb.UCPRoutesTest do
  use MyAppWeb.ConnCase, async: true

  describe "GET /.well-known/ucp" do
    test "returns discovery profile", %{conn: conn} do
      conn = get(conn, "/.well-known/ucp")

      assert json_response(conn, 200)
      assert json_response(conn, 200)["name"] == "My Store"
      assert is_list(json_response(conn, 200)["capabilities"])
    end
  end

  describe "POST /checkout-sessions" do
    test "creates checkout with valid params", %{conn: conn} do
      params = %{
        currency: "USD",
        line_items: [
          %{sku: "TEST-1", quantity: 1, unit_price: "19.99"}
        ]
      }

      conn = post(conn, "/checkout-sessions", params)

      assert %{"id" => _id} = json_response(conn, 201)
    end

    test "returns 422 for invalid params", %{conn: conn} do
      params = %{currency: "INVALID"}

      conn = post(conn, "/checkout-sessions", params)

      assert %{"error" => "validation_error"} = json_response(conn, 422)
    end
  end

  describe "GET /checkout-sessions/:id" do
    test "returns checkout when found", %{conn: conn} do
      # Create a checkout first
      create_conn = post(conn, "/checkout-sessions", valid_checkout_params())
      %{"id" => id} = json_response(create_conn, 201)

      # Fetch it
      conn = get(conn, "/checkout-sessions/#{id}")

      assert json_response(conn, 200)["id"] == id
    end

    test "returns 404 when not found", %{conn: conn} do
      conn = get(conn, "/checkout-sessions/nonexistent")

      assert json_response(conn, 404)["error"] == "not_found"
    end
  end

  defp valid_checkout_params do
    %{
      currency: "USD",
      line_items: [%{sku: "ABC", quantity: 1, unit_price: "10.00"}]
    }
  end
end
```

## Testing Plugs

### UCPHeaders Plug

```elixir
defmodule Bazaar.Plugs.UCPHeadersTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  alias Bazaar.Plugs.UCPHeaders

  test "extracts UCP-Agent header" do
    conn =
      conn(:post, "/")
      |> put_req_header("ucp-agent", "test-agent/1.0")
      |> UCPHeaders.call([])

    assert conn.assigns[:ucp_agent] == "test-agent/1.0"
  end

  test "generates request ID when not provided" do
    conn =
      conn(:post, "/")
      |> UCPHeaders.call([])

    assert conn.assigns[:ucp_request_id]
    assert String.starts_with?(conn.assigns[:ucp_request_id], "req_")
  end

  test "uses provided request ID" do
    conn =
      conn(:post, "/")
      |> put_req_header("ucp-request-id", "custom_id")
      |> UCPHeaders.call([])

    assert conn.assigns[:ucp_request_id] == "custom_id"
  end
end
```

### ValidateRequest Plug

```elixir
defmodule Bazaar.Plugs.ValidateRequestTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  alias Bazaar.Plugs.ValidateRequest

  setup do
    {:ok, opts: ValidateRequest.init([])}
  end

  test "validates create_checkout action", %{opts: opts} do
    conn =
      conn(:post, "/checkout-sessions")
      |> put_private(:phoenix_action, :create_checkout)
      |> Map.put(:params, %{
        "currency" => "USD",
        "line_items" => [%{"sku" => "ABC", "quantity" => 1, "unit_price" => "10.00"}]
      })
      |> ValidateRequest.call(opts)

    refute conn.halted
    assert conn.assigns[:bazaar_validated]
  end

  test "returns 422 for invalid request", %{opts: opts} do
    conn =
      conn(:post, "/checkout-sessions")
      |> put_private(:phoenix_action, :create_checkout)
      |> Map.put(:params, %{"currency" => "INVALID"})
      |> ValidateRequest.call(opts)

    assert conn.halted
    assert conn.status == 422
  end
end
```

### Idempotency Plug

```elixir
defmodule Bazaar.Plugs.IdempotencyTest do
  use ExUnit.Case, async: false

  import Plug.Test
  import Plug.Conn

  alias Bazaar.Plugs.Idempotency
  alias Bazaar.Plugs.Idempotency.ETSCache

  setup do
    # Clear cache between tests
    if :ets.whereis(:bazaar_idempotency_cache) != :undefined do
      :ets.delete_all_objects(:bazaar_idempotency_cache)
    end

    {:ok, opts: Idempotency.init([])}
  end

  test "passes through without idempotency key", %{opts: opts} do
    conn =
      conn(:post, "/checkout-sessions")
      |> Idempotency.call(opts)

    refute conn.halted
  end

  test "returns cached response for duplicate request", %{opts: opts} do
    cache_key = "POST:/checkout-sessions:test-key"

    ETSCache.put(cache_key, %{
      status: 201,
      headers: [],
      body: ~s({"id":"cached"})
    }, 3600)

    conn =
      conn(:post, "/checkout-sessions")
      |> put_req_header("idempotency-key", "test-key")
      |> Idempotency.call(opts)

    assert conn.halted
    assert conn.status == 201
    assert get_resp_header(conn, "idempotency-replay") == ["true"]
  end
end
```

## Integration Tests

### Full Flow Test

```elixir
defmodule MyAppWeb.CheckoutFlowTest do
  use MyAppWeb.ConnCase, async: true

  test "complete checkout flow", %{conn: conn} do
    # 1. Create checkout
    create_params = %{
      currency: "USD",
      line_items: [
        %{sku: "LAPTOP-1", name: "Laptop", quantity: 1, unit_price: "999.99"}
      ]
    }

    conn = post(conn, "/checkout-sessions", create_params)
    assert %{"id" => checkout_id, "status" => "open"} = json_response(conn, 201)

    # 2. Update with buyer info
    update_params = %{
      buyer: %{email: "test@example.com", name: "Test User"},
      shipping_address: %{
        line1: "123 Main St",
        city: "NYC",
        state: "NY",
        postal_code: "10001",
        country: "US"
      }
    }

    conn = patch(conn, "/checkout-sessions/#{checkout_id}", update_params)
    assert json_response(conn, 200)["buyer"]["email"] == "test@example.com"

    # 3. Get checkout to verify
    conn = get(conn, "/checkout-sessions/#{checkout_id}")
    checkout = json_response(conn, 200)

    assert checkout["id"] == checkout_id
    assert checkout["buyer"]["email"] == "test@example.com"
  end
end
```

## Test Helpers

Create a test helper module:

```elixir
# test/support/ucp_helpers.ex
defmodule MyApp.UCPHelpers do
  def valid_checkout_params(overrides \\ %{}) do
    Map.merge(
      %{
        "currency" => "USD",
        "line_items" => [
          %{
            "sku" => "TEST-#{System.unique_integer([:positive])}",
            "name" => "Test Product",
            "quantity" => 1,
            "unit_price" => "19.99"
          }
        ]
      },
      overrides
    )
  end

  def valid_order_params(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "order_#{System.unique_integer([:positive])}",
        "status" => "pending",
        "currency" => "USD",
        "total" => "19.99",
        "line_items" => [
          %{"sku" => "TEST-1", "quantity" => 1, "unit_price" => "19.99"}
        ]
      },
      overrides
    )
  end
end
```

## Running Tests

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific file
mix test test/my_app/commerce/handler_test.exs

# Run specific test
mix test test/my_app/commerce/handler_test.exs:42
```

## Tips

### Use async: true

Most Bazaar tests can run in parallel:

```elixir
use ExUnit.Case, async: true
```

Exception: Tests using the idempotency ETS cache should use `async: false`.

### Test Edge Cases

Always test:
- Missing required fields
- Invalid field values
- Not found scenarios
- State transition errors (e.g., cancelling already cancelled)

### Mock External Services

For handlers that call external APIs:

```elixir
# Using Mox
defmock(MyApp.PaymentMock, for: MyApp.PaymentBehaviour)

test "handles payment failure" do
  expect(MyApp.PaymentMock, :charge, fn _ ->
    {:error, :card_declined}
  end)

  # ... test code
end
```

## Next Steps

- Review [Handlers Guide](handlers.md) for callback patterns
- Check [Schemas Guide](schemas.md) for validation details
- See [Plugs Guide](plugs.md) for middleware testing
