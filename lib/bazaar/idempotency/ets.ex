defmodule Bazaar.Idempotency.ETS do
  @moduledoc """
  In-memory idempotency store on a named ETS table, started the first time a
  request carries an `Idempotency-Key`, so there is nothing to add to your
  supervision tree.

  Records never expire and live until the process restarts, which is fine for
  development and a single node. In production, and always with more than one
  node, use a `Bazaar.Idempotency.Store` on Cachex or your database instead.
  """

  @behaviour Bazaar.Idempotency.Store

  use GenServer

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, name, name: name)
  end

  def child_spec(opts) do
    %{id: Keyword.get(opts, :name, __MODULE__), start: {__MODULE__, :start_link, [opts]}}
  end

  @impl GenServer
  def init(name) do
    :ets.new(name, [:named_table, :public, :set, read_concurrency: true])
    {:ok, name}
  end

  @impl Bazaar.Idempotency.Store
  def fetch(table, key) do
    case :ets.lookup(running!(table), key) do
      [{^key, record}] -> {:ok, record}
      [] -> :error
    end
  end

  @impl Bazaar.Idempotency.Store
  def reserve(table, key, reservation) do
    if :ets.insert_new(running!(table), {key, reservation}), do: :ok, else: {:error, :taken}
  end

  @impl Bazaar.Idempotency.Store
  def put(table, key, response) do
    :ets.insert(running!(table), {key, response})
    :ok
  end

  @impl Bazaar.Idempotency.Store
  def release(table, key) do
    :ets.delete(running!(table), key)
    :ok
  end

  # Started the first time a request carries an Idempotency-Key, so an app
  # with a Cachex or database store never starts it.
  defp running!(table) do
    if :ets.whereis(table) == :undefined do
      Bazaar.Application.ensure_started({__MODULE__, name: table})
    end

    table
  end
end
