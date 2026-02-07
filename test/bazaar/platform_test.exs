defmodule Bazaar.PlatformTest do
  use ExUnit.Case, async: true

  alias Bazaar.Platform

  @valid_profile %{
    "name" => "dev.ucp.example.platform",
    "version" => "2026-01-23",
    "capabilities" => ["dev.ucp.shopping.checkout", "dev.ucp.shopping.order"],
    "webhook_url" => "https://platform.example.com/webhooks/ucp",
    "webhook_secret" => "whsec_test123"
  }

  @agent_uri "https://platform.example.com"

  describe "discover/2" do
    test "fetches and parses platform discovery profile" do
      http_client = fn url ->
        assert url == "https://platform.example.com/.well-known/ucp"
        {:ok, %{status: 200, body: JSON.encode!(@valid_profile)}}
      end

      assert {:ok, profile} = Platform.discover(@agent_uri, http_client: http_client)
      assert profile["name"] == "dev.ucp.example.platform"
      assert profile["webhook_url"] == "https://platform.example.com/webhooks/ucp"
    end

    test "handles trailing slash in agent URI" do
      http_client = fn url ->
        assert url == "https://platform.example.com/.well-known/ucp"
        {:ok, %{status: 200, body: JSON.encode!(@valid_profile)}}
      end

      assert {:ok, _} =
               Platform.discover("https://platform.example.com/", http_client: http_client)
    end

    test "returns error for non-200 response" do
      http_client = fn _url ->
        {:ok, %{status: 404, body: "Not found"}}
      end

      assert {:error, {:http_error, 404}} =
               Platform.discover(@agent_uri, http_client: http_client)
    end

    test "returns error for invalid JSON" do
      http_client = fn _url ->
        {:ok, %{status: 200, body: "not json"}}
      end

      assert {:error, {:json_error, _}} = Platform.discover(@agent_uri, http_client: http_client)
    end

    test "returns error for HTTP client failure" do
      http_client = fn _url ->
        {:error, :connection_refused}
      end

      assert {:error, :connection_refused} =
               Platform.discover(@agent_uri, http_client: http_client)
    end
  end

  describe "discovery_url/1" do
    test "appends well-known path to agent URI" do
      assert Platform.discovery_url("https://example.com") ==
               "https://example.com/.well-known/ucp"
    end

    test "handles trailing slash" do
      assert Platform.discovery_url("https://example.com/") ==
               "https://example.com/.well-known/ucp"
    end

    test "handles path in agent URI" do
      assert Platform.discovery_url("https://example.com/api") ==
               "https://example.com/api/.well-known/ucp"
    end
  end

  describe "caching with discover_cached/3" do
    test "caches profile after first fetch" do
      call_count = :counters.new(1, [:atomics])

      http_client = fn _url ->
        :counters.add(call_count, 1, 1)
        {:ok, %{status: 200, body: JSON.encode!(@valid_profile)}}
      end

      cache = start_test_cache()

      # First call should fetch
      assert {:ok, _} = Platform.discover_cached(@agent_uri, cache, http_client: http_client)
      assert :counters.get(call_count, 1) == 1

      # Second call should use cache
      assert {:ok, profile} =
               Platform.discover_cached(@agent_uri, cache, http_client: http_client)

      assert :counters.get(call_count, 1) == 1
      assert profile["webhook_url"] == "https://platform.example.com/webhooks/ucp"
    end

    test "different URIs have separate cache entries" do
      http_client = fn url ->
        name =
          if String.contains?(url, "platform1") do
            "platform1"
          else
            "platform2"
          end

        {:ok, %{status: 200, body: JSON.encode!(Map.put(@valid_profile, "name", name))}}
      end

      cache = start_test_cache()

      assert {:ok, p1} =
               Platform.discover_cached("https://platform1.com", cache, http_client: http_client)

      assert {:ok, p2} =
               Platform.discover_cached("https://platform2.com", cache, http_client: http_client)

      assert p1["name"] == "platform1"
      assert p2["name"] == "platform2"
    end
  end

  # Helper to create an ETS-based test cache
  defp start_test_cache do
    table = :ets.new(:test_platform_cache, [:set, :public])

    %{
      get: fn key ->
        case :ets.lookup(table, key) do
          [{^key, value}] -> {:ok, value}
          [] -> :miss
        end
      end,
      put: fn key, value ->
        :ets.insert(table, {key, value})
        :ok
      end
    }
  end
end
