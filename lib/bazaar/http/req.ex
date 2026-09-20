if Code.ensure_loaded?(Req) do
  defmodule Bazaar.Http.Req do
    @moduledoc """
    The HTTP client `Bazaar.Shop`'s `http_client/0` returns by default when
    [Req](https://hex.pm/packages/req) is available: what bazaar needs to
    fetch a platform's profile and deliver an order webhook.

        @impl true
        def http_client, do: Bazaar.Http.Req.client()

    Retries are off here because `Bazaar.Webhook.deliver/2` owns them: it
    retries the same body, id and timestamp so a platform can deduplicate.
    `client/1` takes any `Req` options (`receive_timeout`, `connect_options`,
    headers for a proxy) when the defaults don't fit.
    """

    @defaults [retry: false, receive_timeout: 5_000]

    @doc "A `%{get: ..., post: ...}` client over Req."
    def client(opts \\ []) do
      opts = Keyword.merge(@defaults, opts)
      %{get: &get(&1, opts), post: &post(&1, &2, &3, opts)}
    end

    @doc false
    def get(url, opts \\ @defaults) do
      case Req.get(url, opts) do
        {:ok, %{status: status, body: body}} -> {:ok, %{status: status, body: body}}
        {:error, reason} -> {:error, reason}
      end
    end

    @doc false
    def post(url, body, headers, opts \\ @defaults) do
      case Req.post(url, [body: body, headers: headers] ++ opts) do
        {:ok, %{status: status, body: body}} -> {:ok, %{status: status, body: body}}
        {:error, reason} -> {:error, reason}
      end
    end
  end
end
