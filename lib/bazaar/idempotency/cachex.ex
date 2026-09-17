if Code.ensure_loaded?(Cachex) do
  defmodule Bazaar.Idempotency.Cachex do
    @moduledoc """
    Idempotency store on a [Cachex](https://hexdocs.pm/cachex) cache, for
    production: entries expire with the cache's default TTL, and Cachex's
    distributed routers keep records visible across nodes.

    Start a cache with a default expiration and point the plug at it:

        # mix.exs
        {:cachex, "~> 4.1"}

        # application.ex
        import Cachex.Spec
        children = [
          {Cachex, [:idempotency, [expiration: expiration(default: :timer.hours(24))]]},
          MyAppWeb.Endpoint
        ]

        # router.ex
        plug Bazaar.Plugs.UCP, store: {Bazaar.Idempotency.Cachex, :idempotency}

    Reservations are claimed inside a Cachex transaction on the key, which is
    what keeps two identical requests in flight from both running.
    """

    @behaviour Bazaar.Idempotency.Store

    @impl true
    def fetch(cache, key) do
      case Cachex.get(cache, key) do
        {:ok, nil} -> :error
        {:ok, record} -> {:ok, record}
      end
    end

    @impl true
    def reserve(cache, key, reservation) do
      {:ok, outcome} =
        Cachex.transaction(cache, [key], fn worker ->
          case Cachex.get(worker, key) do
            {:ok, nil} ->
              {:ok, true} = Cachex.put(worker, key, reservation)
              :ok

            {:ok, _taken} ->
              {:error, :taken}
          end
        end)

      outcome
    end

    @impl true
    def put(cache, key, response) do
      {:ok, true} = Cachex.put(cache, key, response)
      :ok
    end

    @impl true
    def release(cache, key) do
      {:ok, _} = Cachex.del(cache, key)
      :ok
    end
  end
end
