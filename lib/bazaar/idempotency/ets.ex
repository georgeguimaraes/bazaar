defmodule Bazaar.Idempotency.ETS do
  @moduledoc """
  In-memory idempotency store on a named ETS table.

  Add it to your supervision tree:

      children = [
        Bazaar.Idempotency.ETS,
        MyAppWeb.Endpoint
      ]

  Records live until the process restarts. That is fine for a single node and
  for development; a multi-node deployment needs a `Bazaar.Idempotency.Store`
  backed by shared storage.
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
  def put(table, key, record) do
    :ets.insert(running!(table), {key, record})
    :ok
  end

  defp running!(table) do
    if :ets.whereis(table) == :undefined do
      raise "idempotency table #{inspect(table)} is not running; add Bazaar.Idempotency.ETS to your supervision tree"
    end

    table
  end
end
