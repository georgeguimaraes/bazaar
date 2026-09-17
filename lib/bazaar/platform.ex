defmodule Bazaar.Platform do
  @moduledoc """
  Platform profiles.

  A platform identifies itself with `UCP-Agent: profile="<url>"`. That URL
  serves the platform's profile document, whose order capability carries the
  `webhook_url` order events go to. `Bazaar.Plugs.UCPHeaders` puts the URL in
  `conn.assigns.ucp_agent_profile`.

  ## HTTP client

  No HTTP client is bundled. Pass a function that GETs a URL and returns
  `{:ok, %{status: integer, body: binary | map}}` or `{:error, reason}`:

      http_client = fn url ->
        case Req.get(url) do
          {:ok, %{status: status, body: body}} -> {:ok, %{status: status, body: body}}
          {:error, reason} -> {:error, reason}
        end
      end

      {:ok, webhook_url} = Bazaar.Platform.webhook_url(profile_url, http_client: http_client)

  ## Caching

  `discover_cached/3` takes a cache map with `get` (returns `{:ok, value}` or
  `:miss`) and `put` functions, so a profile is fetched once per platform.
  """

  @order_capability "dev.ucp.shopping.order"

  @doc """
  Fetches and parses a platform profile.

  Returns `{:ok, profile}`, `{:error, {:http_error, status}}`,
  `{:error, {:json_error, reason}}` or the HTTP client's error.
  """
  def discover(profile_url, opts) when is_binary(profile_url) do
    http_client = Keyword.fetch!(opts, :http_client)

    case http_client.(profile_url) do
      {:ok, %{status: 200, body: body}} -> parse_profile(body)
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Like `discover/2`, reading and filling a cache keyed by the profile URL."
  def discover_cached(profile_url, cache, opts) do
    case cache.get.({:platform, profile_url}) do
      {:ok, profile} ->
        {:ok, profile}

      :miss ->
        with {:ok, profile} = result <- discover(profile_url, opts) do
          cache.put.({:platform, profile_url}, profile)
          result
        end
    end
  end

  @doc """
  The URL a platform wants order events delivered to, read from the order
  capability of its profile.

  Returns `{:ok, url}`, `{:error, :webhook_url_not_advertised}` or a
  `discover/2` error.
  """
  def webhook_url(profile_url, opts) do
    with {:ok, profile} <- discover(profile_url, opts) do
      profile
      |> get_in(["ucp", "capabilities", @order_capability])
      |> List.wrap()
      |> Enum.find_value(&get_in(&1, ["config", "webhook_url"]))
      |> case do
        url when is_binary(url) -> {:ok, url}
        _ -> {:error, :webhook_url_not_advertised}
      end
    end
  end

  defp parse_profile(body) when is_map(body), do: {:ok, body}

  defp parse_profile(body) when is_binary(body) do
    case JSON.decode(body) do
      {:ok, profile} -> {:ok, profile}
      {:error, reason} -> {:error, {:json_error, reason}}
    end
  end
end
