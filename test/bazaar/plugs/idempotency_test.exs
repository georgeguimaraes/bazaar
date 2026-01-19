defmodule Bazaar.Plugs.IdempotencyTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  alias Bazaar.Plugs.Idempotency

  describe "init/1" do
    test "returns opts unchanged" do
      assert Idempotency.init([]) == []
      assert Idempotency.init(foo: :bar) == [foo: :bar]
    end
  end

  describe "call/2 without idempotency key" do
    test "passes through without idempotency key" do
      opts = Idempotency.init([])

      conn =
        conn(:post, "/checkout-sessions")
        |> Idempotency.call(opts)

      refute conn.halted
      refute conn.assigns[:idempotency_key]
    end

    test "passes through with empty idempotency key" do
      opts = Idempotency.init([])

      conn =
        conn(:post, "/checkout-sessions")
        |> put_req_header("idempotency-key", "")
        |> Idempotency.call(opts)

      refute conn.halted
      refute conn.assigns[:idempotency_key]
    end
  end

  describe "call/2 with idempotency key" do
    test "assigns idempotency key" do
      opts = Idempotency.init([])

      conn =
        conn(:post, "/checkout-sessions")
        |> put_req_header("idempotency-key", "test-key-123")
        |> Idempotency.call(opts)

      refute conn.halted
      assert conn.assigns[:idempotency_key] == "test-key-123"
    end

    test "echoes idempotency key in response header" do
      opts = Idempotency.init([])

      conn =
        conn(:post, "/checkout-sessions")
        |> put_req_header("idempotency-key", "test-key-456")
        |> Idempotency.call(opts)

      assert get_resp_header(conn, "idempotency-key") == ["test-key-456"]
    end

    test "handles multiple requests with different keys" do
      opts = Idempotency.init([])

      conn1 =
        conn(:post, "/checkout-sessions")
        |> put_req_header("idempotency-key", "key-1")
        |> Idempotency.call(opts)

      conn2 =
        conn(:post, "/checkout-sessions")
        |> put_req_header("idempotency-key", "key-2")
        |> Idempotency.call(opts)

      assert conn1.assigns[:idempotency_key] == "key-1"
      assert conn2.assigns[:idempotency_key] == "key-2"
    end
  end
end
