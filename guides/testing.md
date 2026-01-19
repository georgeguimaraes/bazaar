# Testing Guide

This guide shows you how to test your Bazaar implementation.

## Testing Handlers

### Basic Handler Test

```elixir
defmodule MyApp.UCPHandlerTest do
  use ExUnit.Case, async: true

  alias MyApp.UCPHandler

  describe "capabilities/0" do
    test "returns expected capabilities" do
      assert UCPHandler.capabilities() == [:checkout, :orders]
    end
  end

  describe "business_profile/0" do
    test "returns store profile" do
      profile = UCPHandler.business_profile()

      assert profile["name"] == "My Store"
      assert is_binary(profile["description"])
    end
  end

  describe "create_checkout/2" do
    test "creates checkout with valid params" do
      params = valid_checkout_params()

      assert {:ok, checkout} = UCPHandler.create_checkout(params, nil)
      assert checkout["currency"] == "USD"
      assert checkout["status"] == "incomplete"
      assert is_list(checkout["totals"])
      assert is_list(checkout["links"])
    end

    test "returns error for invalid params" do
      params = %{"currency" => "INVALID"}

      assert {:error, _} = UCPHandler.create_checkout(params, nil)
    end
  end

  describe "get_checkout/2" do
    test "returns checkout when found" do
      # Setup: create a checkout first
      {:ok, created} = UCPHandler.create_checkout(valid_checkout_params(), nil)

      assert {:ok, checkout} = UCPHandler.get_checkout(created["id"], nil)
      assert checkout["id"] == created["id"]
    end

    test "returns not_found for missing checkout" do
      assert {:error, :not_found} = UCPHandler.get_checkout("nonexistent", nil)
    end
  end

  defp valid_checkout_params do
    %{
      "currency" => "USD",
      "line_items" => [
        %{"item" => %{"id" => "TEST-1"}, "quantity" => 1}
      ],
      "payment" => %{}
    }
  end
end
```

### Testing with Database

```elixir
defmodule MyApp.UCPHandlerTest do
  use MyApp.DataCase, async: true

  alias MyApp.UCPHandler
  alias MyApp.Repo

  setup do
    # Clean up before each test
    :ok
  end

  describe "create_checkout/2" do
    test "persists checkout to database" do
      params = valid_checkout_params()

      {:ok, checkout} = UCPHandler.create_checkout(params, nil)

      # Verify it's in the database
      assert Repo.get!(MyApp.Checkout, checkout["id"])
    end
  end

  describe "cancel_checkout/2" do
    test "updates status to canceled" do
      {:ok, checkout} = UCPHandler.create_checkout(valid_checkout_params(), nil)

      {:ok, cancelled} = UCPHandler.cancel_checkout(checkout["id"], nil)

      assert cancelled["status"] == "canceled"

      # Verify in database
      db_checkout = Repo.get!(MyApp.Checkout, checkout["id"])
      assert db_checkout.status == :canceled
    end
  end

  defp valid_checkout_params do
    %{
      "currency" => "USD",
      "line_items" => [
        %{"item" => %{"id" => "TEST-1"}, "quantity" => 1}
      ],
      "payment" => %{}
    }
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
          %{"item" => %{"id" => "ABC"}, "quantity" => 1}
        ],
        "payment" => %{}
      }

      changeset = CheckoutSession.new(params)

      assert changeset.valid?
    end

    test "requires currency" do
      params = %{
        "line_items" => [
          %{"item" => %{"id" => "ABC"}, "quantity" => 1}
        ],
        "payment" => %{}
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).currency
    end

    test "requires line_items" do
      params = %{
        "currency" => "USD",
        "payment" => %{}
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).line_items
    end

    test "requires payment" do
      params = %{
        "currency" => "USD",
        "line_items" => [%{"item" => %{"id" => "ABC"}, "quantity" => 1}]
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).payment
    end

    test "validates currency format" do
      params = %{
        "currency" => "INVALID",
        "line_items" => [%{"item" => %{"id" => "ABC"}, "quantity" => 1}],
        "payment" => %{}
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).currency
    end

    test "requires at least one line item" do
      params = %{
        "currency" => "USD",
        "line_items" => [],
        "payment" => %{}
      }

      changeset = CheckoutSession.new(params)

      refute changeset.valid?
    end

    test "validates line item quantity >= 1" do
      params = %{
        "currency" => "USD",
        "line_items" => [
          %{"item" => %{"id" => "ABC"}, "quantity" => 0}
        ],
        "payment" => %{}
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

  describe "from_checkout/3" do
    test "creates order from checkout data" do
      checkout = %{
        "id" => "checkout_123",
        "currency" => "USD",
        "line_items" => [
          %{
            "item" => %{"id" => "ABC", "title" => "Widget", "price" => 1999},
            "quantity" => 1,
            "totals" => [%{"type" => "subtotal", "amount" => 1999}]
          }
        ],
        "totals" => [
          %{"type" => "subtotal", "amount" => 1999},
          %{"type" => "total", "amount" => 1999}
        ]
      }

      changeset = Order.from_checkout(checkout, "order_456", "https://shop.example/orders/456")

      assert changeset.valid?

      order = Ecto.Changeset.apply_changes(changeset)
      assert order.id == "order_456"
      assert order.checkout_id == "checkout_123"
      assert order.permalink_url == "https://shop.example/orders/456"
    end
  end

  describe "new/1" do
    test "requires id, checkout_id, permalink_url, line_items, totals" do
      changeset = Order.new(%{})

      refute changeset.valid?
      errors = errors_on(changeset)
      assert "can't be blank" in errors.id
      assert "can't be blank" in errors.checkout_id
      assert "can't be blank" in errors.permalink_url
      assert "can't be blank" in errors.line_items
      assert "can't be blank" in errors.totals
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
```

## Testing Against Official UCP Schemas

Use `Bazaar.Validator` to ensure your responses match the official UCP spec:

```elixir
defmodule MyApp.UCPConformanceTest do
  use ExUnit.Case, async: true

  alias MyApp.UCPHandler

  describe "checkout response conformance" do
    test "checkout response matches UCP spec" do
      params = valid_checkout_params()

      {:ok, checkout} = UCPHandler.create_checkout(params, nil)

      # Validate against official UCP JSON Schema
      assert {:ok, _} = Bazaar.Validator.validate_checkout(checkout)
    end

    test "checkout with all fields matches UCP spec" do
      checkout = %{
        "ucp" => %{
          "version" => "2026-01-11",
          "capabilities" => [
            %{"name" => "dev.ucp.shopping.checkout", "version" => "2026-01-11"}
          ]
        },
        "id" => "checkout_123",
        "status" => "incomplete",
        "currency" => "USD",
        "line_items" => [
          %{
            "id" => "li_1",
            "item" => %{"id" => "PROD-1", "title" => "Widget", "price" => 1999},
            "quantity" => 2,
            "totals" => [%{"type" => "subtotal", "amount" => 3998}]
          }
        ],
        "totals" => [
          %{"type" => "subtotal", "amount" => 3998},
          %{"type" => "total", "amount" => 3998}
        ],
        "links" => [
          %{"type" => "privacy_policy", "url" => "https://example.com/privacy"},
          %{"type" => "terms_of_service", "url" => "https://example.com/terms"}
        ],
        "payment" => %{"handlers" => []}
      }

      assert {:ok, _} = Bazaar.Validator.validate_checkout(checkout)
    end
  end

  describe "order response conformance" do
    test "order response matches UCP spec" do
      order = %{
        "ucp" => %{
          "version" => "2026-01-11",
          "capabilities" => [
            %{"name" => "dev.ucp.shopping.order", "version" => "2026-01-11"}
          ]
        },
        "id" => "order_123",
        "checkout_id" => "checkout_456",
        "permalink_url" => "https://shop.example/orders/123",
        "line_items" => [
          %{
            "id" => "li_1",
            "item" => %{"id" => "PROD-1", "title" => "Widget", "price" => 1999},
            "quantity" => %{"total" => 2, "fulfilled" => 0},
            "totals" => [%{"type" => "subtotal", "amount" => 3998}],
            "status" => "processing"
          }
        ],
        "fulfillment" => %{
          "expectations" => [],
          "events" => []
        },
        "totals" => [
          %{"type" => "total", "amount" => 3998}
        ]
      }

      assert {:ok, _} = Bazaar.Validator.validate_order(order)
    end
  end

  defp valid_checkout_params do
    %{
      "currency" => "USD",
      "line_items" => [
        %{"item" => %{"id" => "TEST-1"}, "quantity" => 1}
      ],
      "payment" => %{}
    }
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
        "currency" => "USD",
        "line_items" => [
          %{"item" => %{"id" => "TEST-1"}, "quantity" => 1}
        ],
        "payment" => %{}
      }

      conn = post(conn, "/checkout-sessions", params)

      assert %{"id" => _id, "status" => "incomplete"} = json_response(conn, 201)
    end

    test "returns 422 for invalid params", %{conn: conn} do
      params = %{"currency" => "INVALID"}

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

  describe "DELETE /checkout-sessions/:id" do
    test "cancels checkout", %{conn: conn} do
      # Create a checkout first
      create_conn = post(conn, "/checkout-sessions", valid_checkout_params())
      %{"id" => id} = json_response(create_conn, 201)

      # Cancel it
      conn = delete(conn, "/checkout-sessions/#{id}")

      assert json_response(conn, 200)["status"] == "canceled"
    end
  end

  defp valid_checkout_params do
    %{
      "currency" => "USD",
      "line_items" => [
        %{"item" => %{"id" => "TEST-1"}, "quantity" => 1}
      ],
      "payment" => %{}
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
        "line_items" => [%{"item" => %{"id" => "ABC"}, "quantity" => 1}],
        "payment" => %{}
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
      "currency" => "USD",
      "line_items" => [
        %{"item" => %{"id" => "LAPTOP-1"}, "quantity" => 1}
      ],
      "payment" => %{}
    }

    conn = post(conn, "/checkout-sessions", create_params)
    assert %{"id" => checkout_id, "status" => "incomplete"} = json_response(conn, 201)

    # 2. Update with buyer info
    update_params = %{
      "buyer" => %{
        "first_name" => "Test",
        "last_name" => "User",
        "email" => "test@example.com"
      },
      "shipping_address" => %{
        "street_address" => "123 Main St",
        "address_locality" => "NYC",
        "address_region" => "NY",
        "postal_code" => "10001",
        "address_country" => "US"
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
            "item" => %{"id" => "TEST-#{System.unique_integer([:positive])}"},
            "quantity" => 1
          }
        ],
        "payment" => %{}
      },
      overrides
    )
  end

  def valid_checkout_response(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "checkout_#{System.unique_integer([:positive])}",
        "status" => "incomplete",
        "currency" => "USD",
        "line_items" => [
          %{
            "item" => %{"id" => "PROD-1", "title" => "Widget", "price" => 1999},
            "quantity" => 1,
            "totals" => [%{"type" => "subtotal", "amount" => 1999}]
          }
        ],
        "totals" => [
          %{"type" => "subtotal", "amount" => 1999},
          %{"type" => "total", "amount" => 1999}
        ],
        "links" => [
          %{"type" => "privacy_policy", "url" => "https://example.com/privacy"},
          %{"type" => "terms_of_service", "url" => "https://example.com/terms"}
        ],
        "payment" => %{"handlers" => []}
      },
      overrides
    )
  end

  def valid_order_response(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "order_#{System.unique_integer([:positive])}",
        "checkout_id" => "checkout_123",
        "permalink_url" => "https://shop.example/orders/123",
        "line_items" => [
          %{
            "item" => %{"id" => "PROD-1", "title" => "Widget", "price" => 1999},
            "quantity" => 1,
            "totals" => [%{"type" => "subtotal", "amount" => 1999}]
          }
        ],
        "totals" => [%{"type" => "total", "amount" => 1999}],
        "fulfillment" => %{"expectations" => [], "events" => []}
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
mix test test/my_app/ucp_handler_test.exs

# Run specific test
mix test test/my_app/ucp_handler_test.exs:42
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

### Test UCP Conformance

Use `Bazaar.Validator` to ensure your responses match the official UCP spec:

```elixir
test "response matches UCP spec" do
  {:ok, checkout} = MyHandler.create_checkout(params, nil)
  assert {:ok, _} = Bazaar.Validator.validate_checkout(checkout)
end
```

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
