defmodule Bazaar.Platform do
  @moduledoc """
  Platform discovery and profile management.

  Platforms identify themselves via the `UCP-Agent` header, which contains
  a URI pointing to their discovery endpoint. This module fetches and caches
  platform profiles from their `/.well-known/ucp` endpoints.

  ## Discovery Flow

  1. Platform sends request with `UCP-Agent: https://platform.example.com`
  2. Merchant fetches `https://platform.example.com/.well-known/ucp`
  3. Profile contains `webhook_url` and `webhook_secret` for sending events

  ## HTTP Client

  This module doesn't include an HTTP client to avoid forcing dependencies.
  Pass an HTTP client function via the `:http_client` option:

      # Using Req
      http_client = fn url ->
        case Req.get(url) do
          {:ok, %{status: status, body: body}} -> {:ok, %{status: status, body: body}}
          {:error, reason} -> {:error, reason}
        end
      end

      Platform.discover(agent_uri, http_client: http_client)

  ## Caching

  Use `discover_cached/3` with a cache implementation to avoid repeated
  fetches. The cache should be a map with `:get` and `:put` functions:

      cache = %{
        get: fn key -> Agent.get(agent, fn m -> Map.fetch(m, key) end) end,
        put: fn key, val -> Agent.update(agent, fn m -> Map.put(m, key, val) end) end
      }
  """

  @well_known_path "/.well-known/ucp"

  @doc """
  Discovers a platform's profile from its UCP-Agent URI.

  ## Options

  - `:http_client` - Required function that takes a URL and returns
    `{:ok, %{status: integer, body: string}}` or `{:error, reason}`

  ## Returns

  - `{:ok, profile}` - Profile map with webhook_url, webhook_secret, etc.
  - `{:error, {:http_error, status}}` - Non-200 HTTP response
  - `{:error, {:json_error, reason}}` - Invalid JSON response
  - `{:error, reason}` - HTTP client error

  ## Example

      {:ok, profile} = Platform.discover("https://platform.example.com",
        http_client: &my_http_get/1)
      webhook_url = Platform.webhook_url(profile)
  """
  def discover(agent_uri, opts \\ []) do
    http_client = Keyword.fetch!(opts, :http_client)
    url = discovery_url(agent_uri)

    case http_client.(url) do
      {:ok, %{status: 200, body: body}} ->
        parse_profile(body)

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Discovers a platform's profile with caching.

  ## Parameters

  - `agent_uri` - The platform's UCP-Agent URI
  - `cache` - Map with `:get` and `:put` functions
  - `opts` - Options including `:http_client`

  ## Cache Interface

  The cache should provide:
  - `get.(key)` - Returns `{:ok, value}` or `:miss`
  - `put.(key, value)` - Stores value, returns `:ok`

  ## Example

      cache = %{
        get: fn key -> MyCache.get(key) end,
        put: fn key, val -> MyCache.put(key, val) end
      }

      {:ok, profile} = Platform.discover_cached(agent_uri, cache,
        http_client: &my_http_get/1)
  """
  def discover_cached(agent_uri, cache, opts \\ []) do
    cache_key = cache_key(agent_uri)

    case cache.get.(cache_key) do
      {:ok, profile} ->
        {:ok, profile}

      :miss ->
        case discover(agent_uri, opts) do
          {:ok, profile} = result ->
            cache.put.(cache_key, profile)
            result

          error ->
            error
        end
    end
  end

  @doc """
  Extracts the webhook URL from a platform profile.

  Returns `nil` if the profile doesn't contain a webhook_url.
  """
  def webhook_url(profile) when is_map(profile) do
    profile["webhook_url"]
  end

  @doc """
  Extracts the webhook secret from a platform profile.

  Returns `nil` if the profile doesn't contain a webhook_secret.
  """
  def webhook_secret(profile) when is_map(profile) do
    profile["webhook_secret"]
  end

  @doc """
  Builds the discovery URL from an agent URI.

  Appends `/.well-known/ucp` to the agent URI, handling trailing slashes.

  ## Examples

      iex> Platform.discovery_url("https://example.com")
      "https://example.com/.well-known/ucp"

      iex> Platform.discovery_url("https://example.com/")
      "https://example.com/.well-known/ucp"

      iex> Platform.discovery_url("https://example.com/api")
      "https://example.com/api/.well-known/ucp"
  """
  def discovery_url(agent_uri) when is_binary(agent_uri) do
    agent_uri
    |> String.trim_trailing("/")
    |> Kernel.<>(@well_known_path)
  end

  defp parse_profile(body) do
    case JSON.decode(body) do
      {:ok, profile} -> {:ok, profile}
      {:error, reason} -> {:error, {:json_error, reason}}
    end
  end

  defp cache_key(agent_uri) do
    {:platform, agent_uri}
  end
end
