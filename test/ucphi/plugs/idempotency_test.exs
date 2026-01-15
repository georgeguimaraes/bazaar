defmodule Ucphi.Plugs.IdempotencyTest do
  use ExUnit.Case, async: false

  import Plug.Test
  import Plug.Conn

  alias Ucphi.Plugs.Idempotency
  alias Ucphi.Plugs.Idempotency.ETSCache

  setup do
    # Clean up ETS table between tests
    if :ets.whereis(:ucphi_idempotency_cache) != :undefined do
      :ets.delete_all_objects(:ucphi_idempotency_cache)
    end

    :ok
  end

  describe "init/1" do
    test "uses default options" do
      opts = Idempotency.init([])

      assert opts[:cache] == ETSCache
      assert opts[:ttl] == 86_400
      assert opts[:header] == "idempotency-key"
    end

    test "allows custom options" do
      opts = Idempotency.init(ttl: 3600, header: "x-idempotency-key")

      assert opts[:ttl] == 3600
      assert opts[:header] == "x-idempotency-key"
    end
  end

  describe "call/2 without idempotency key" do
    test "passes through without idempotency key" do
      opts = Idempotency.init([])

      conn =
        conn(:post, "/checkout-sessions")
        |> Idempotency.call(opts)

      refute conn.halted
      refute conn.assigns[:ucphi_idempotency_key]
    end

    test "passes through with empty idempotency key" do
      opts = Idempotency.init([])

      conn =
        conn(:post, "/checkout-sessions")
        |> put_req_header("idempotency-key", "")
        |> Idempotency.call(opts)

      refute conn.halted
      refute conn.assigns[:ucphi_idempotency_key]
    end
  end

  describe "call/2 with idempotency key (first request)" do
    test "sets idempotency assigns for new request" do
      opts = Idempotency.init([])

      conn =
        conn(:post, "/checkout-sessions")
        |> put_req_header("idempotency-key", "test-key-123")
        |> Idempotency.call(opts)

      refute conn.halted
      assert conn.assigns[:ucphi_idempotency_key] == "POST:/checkout-sessions:test-key-123"
      assert conn.assigns[:ucphi_idempotency_cache] == ETSCache
      assert conn.assigns[:ucphi_idempotency_ttl] == 86_400
    end

    test "echoes idempotency key in response header" do
      opts = Idempotency.init([])

      conn =
        conn(:post, "/checkout-sessions")
        |> put_req_header("idempotency-key", "test-key-456")
        |> Idempotency.call(opts)

      assert get_resp_header(conn, "idempotency-key") == ["test-key-456"]
    end

    test "registers before_send callback" do
      opts = Idempotency.init([])

      conn =
        conn(:post, "/checkout-sessions")
        |> put_req_header("idempotency-key", "test-key-789")
        |> Idempotency.call(opts)

      # The callback should be registered in conn.private.before_send
      assert length(conn.private[:before_send] || []) > 0
    end
  end

  describe "call/2 with cached response" do
    test "returns cached response for duplicate request" do
      opts = Idempotency.init([])
      cache_key = "POST:/checkout-sessions:cached-key"

      # Pre-populate cache
      ETSCache.put(
        cache_key,
        %{
          status: 201,
          headers: [{"content-type", "application/json"}],
          body: ~s({"id":"checkout_123"})
        },
        3600
      )

      conn =
        conn(:post, "/checkout-sessions")
        |> put_req_header("idempotency-key", "cached-key")
        |> Idempotency.call(opts)

      assert conn.halted
      assert conn.status == 201
      assert conn.resp_body == ~s({"id":"checkout_123"})
    end

    test "sets idempotency-replay header for cached response" do
      opts = Idempotency.init([])
      cache_key = "POST:/checkout-sessions:replay-key"

      ETSCache.put(
        cache_key,
        %{
          status: 200,
          headers: [],
          body: ~s({"status":"ok"})
        },
        3600
      )

      conn =
        conn(:post, "/checkout-sessions")
        |> put_req_header("idempotency-key", "replay-key")
        |> Idempotency.call(opts)

      assert get_resp_header(conn, "idempotency-replay") == ["true"]
      assert get_resp_header(conn, "idempotency-key") == ["replay-key"]
    end
  end

  describe "cache key building" do
    test "includes method in cache key" do
      opts = Idempotency.init([])

      post_conn =
        conn(:post, "/checkout-sessions")
        |> put_req_header("idempotency-key", "same-key")
        |> Idempotency.call(opts)

      patch_conn =
        conn(:patch, "/checkout-sessions/123")
        |> put_req_header("idempotency-key", "same-key")
        |> Idempotency.call(opts)

      # Different methods should have different cache keys
      refute post_conn.assigns[:ucphi_idempotency_key] ==
               patch_conn.assigns[:ucphi_idempotency_key]
    end

    test "includes path in cache key" do
      opts = Idempotency.init([])

      conn1 =
        conn(:post, "/checkout-sessions")
        |> put_req_header("idempotency-key", "same-key")
        |> Idempotency.call(opts)

      conn2 =
        conn(:post, "/orders")
        |> put_req_header("idempotency-key", "same-key")
        |> Idempotency.call(opts)

      # Different paths should have different cache keys
      refute conn1.assigns[:ucphi_idempotency_key] == conn2.assigns[:ucphi_idempotency_key]
    end
  end

  describe "ETSCache" do
    test "stores and retrieves values" do
      ETSCache.put("test-key", %{data: "test"}, 3600)

      assert {:ok, %{data: "test"}} = ETSCache.get("test-key")
    end

    test "returns :miss for non-existent keys" do
      assert :miss = ETSCache.get("non-existent-key")
    end

    test "expires entries after TTL" do
      # Store with 0 TTL (already expired)
      ETSCache.put("expired-key", %{data: "test"}, 0)

      # Wait a moment to ensure time has passed
      Process.sleep(10)

      assert :miss = ETSCache.get("expired-key")
    end

    test "deletes entries" do
      ETSCache.put("delete-key", %{data: "test"}, 3600)
      assert {:ok, _} = ETSCache.get("delete-key")

      ETSCache.delete("delete-key")
      assert :miss = ETSCache.get("delete-key")
    end
  end

  describe "custom header name" do
    test "uses custom idempotency header" do
      opts = Idempotency.init(header: "x-custom-idempotency")

      conn =
        conn(:post, "/checkout-sessions")
        |> put_req_header("x-custom-idempotency", "custom-key")
        |> Idempotency.call(opts)

      refute conn.halted
      assert conn.assigns[:ucphi_idempotency_key] =~ "custom-key"
      assert get_resp_header(conn, "x-custom-idempotency") == ["custom-key"]
    end
  end
end
