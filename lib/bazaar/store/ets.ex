defmodule Bazaar.Store.ETS do
  @moduledoc """
  In-memory `Bazaar.Store` on a named ETS table, started the first time a
  handler uses it, so there is nothing to add to your supervision tree.

  Everything lives until the process restarts, which is fine for development
  and a single node. In production keep checkouts, carts and orders in your
  database with `Bazaar.Store.Ecto` or your own `Bazaar.Store`.
  """

  @behaviour Bazaar.Store

  use GenServer

  @table __MODULE__

  def start_link(_opts \\ []), do: GenServer.start_link(__MODULE__, @table, name: __MODULE__)

  @impl GenServer
  def init(table) do
    :ets.new(table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, table}
  end

  @impl Bazaar.Store
  def get_checkout(id), do: get({:checkout, id})

  @impl Bazaar.Store
  def put_checkout(%{id: id} = state), do: put({:checkout, id}, state)

  @impl Bazaar.Store
  def get_cart(id), do: get({:cart, id})

  @impl Bazaar.Store
  def put_cart(%{id: id} = state), do: put({:cart, id}, state)

  @impl Bazaar.Store
  def delete_cart(id) do
    :ets.delete(running!(), {:cart, id})
    :ok
  end

  @impl Bazaar.Store
  def get_order(id), do: get({:order, id})

  @impl Bazaar.Store
  def put_order(%{"id" => id} = order), do: put({:order, id}, order)

  @impl Bazaar.Store
  def checkout_for_cart(cart_id), do: get({:checkout_for_cart, cart_id})

  @impl Bazaar.Store
  def put_checkout_for_cart(cart_id, checkout_id) do
    put({:checkout_for_cart, cart_id}, checkout_id)
    :ok
  end

  defp get(key) do
    case :ets.lookup(running!(), key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  defp put(key, value) do
    :ets.insert(running!(), {key, value})
    value
  end

  # Started the first time something reads or writes it, so an app that keeps
  # its checkouts elsewhere never pays for the table.
  defp running! do
    if :ets.whereis(@table) == :undefined, do: Bazaar.Application.ensure_started(__MODULE__)
    @table
  end
end
