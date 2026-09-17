defmodule Bazaar.PlatformTest do
  use ExUnit.Case, async: true

  alias Bazaar.Platform

  @profile_url "http://localhost:8285/profiles/shopping-agent.json"

  @profile %{
    "ucp" => %{
      "version" => "2026-08-25",
      "capabilities" => %{
        "dev.ucp.shopping.order" => [
          %{
            "version" => "2026-08-25",
            "config" => %{
              "webhook_url" => "http://localhost:8284/webhooks/partners/test/events/order"
            }
          }
        ]
      }
    }
  }

  defp client(response), do: fn _url -> response end

  describe "discover/2" do
    test "fetches the profile URL as given and parses a JSON body" do
      http_client = fn url ->
        assert url == @profile_url
        {:ok, %{status: 200, body: JSON.encode!(@profile)}}
      end

      assert {:ok, @profile} = Platform.discover(@profile_url, http_client: http_client)
    end

    test "accepts a body the client already decoded" do
      assert {:ok, @profile} =
               Platform.discover(@profile_url,
                 http_client: client({:ok, %{status: 200, body: @profile}})
               )
    end

    test "surfaces http, json and transport errors" do
      assert {:error, {:http_error, 404}} =
               Platform.discover(@profile_url,
                 http_client: client({:ok, %{status: 404, body: ""}})
               )

      assert {:error, {:json_error, _}} =
               Platform.discover(@profile_url,
                 http_client: client({:ok, %{status: 200, body: "nope"}})
               )

      assert {:error, :econnrefused} =
               Platform.discover(@profile_url, http_client: client({:error, :econnrefused}))
    end
  end

  describe "webhook_url/2" do
    test "reads the order capability's webhook_url" do
      assert {:ok, "http://localhost:8284/webhooks/partners/test/events/order"} =
               Platform.webhook_url(@profile_url,
                 http_client: client({:ok, %{status: 200, body: @profile}})
               )
    end

    test "reports a profile without one" do
      profile = put_in(@profile, ["ucp", "capabilities"], %{})

      assert {:error, :webhook_url_not_advertised} =
               Platform.webhook_url(@profile_url,
                 http_client: client({:ok, %{status: 200, body: profile}})
               )
    end
  end

  describe "discover_cached/3" do
    test "fetches once and serves the cache afterwards" do
      {:ok, store} = Agent.start_link(fn -> %{} end)

      cache = %{
        get: fn key ->
          Agent.get(store, &Map.fetch(&1, key)) |> then(&if(&1 == :error, do: :miss, else: &1))
        end,
        put: fn key, value -> Agent.update(store, &Map.put(&1, key, value)) end
      }

      {:ok, counter} = Agent.start_link(fn -> 0 end)

      http_client = fn _url ->
        Agent.update(counter, &(&1 + 1))
        {:ok, %{status: 200, body: @profile}}
      end

      assert {:ok, @profile} =
               Platform.discover_cached(@profile_url, cache, http_client: http_client)

      assert {:ok, @profile} =
               Platform.discover_cached(@profile_url, cache, http_client: http_client)

      assert Agent.get(counter, & &1) == 1
    end
  end
end
