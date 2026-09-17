defmodule FlowerShop.Store do
  @moduledoc """
  In-memory state: checkouts, orders and idempotency records. An Agent is all a
  demo merchant needs, and it keeps the example free of a database.
  """

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{checkouts: %{}, orders: %{}, idempotency: %{}} end, name: __MODULE__)
  end

  def get_checkout(id), do: Agent.get(__MODULE__, &Map.get(&1.checkouts, id))

  def put_checkout(%{id: id} = checkout) do
    Agent.update(__MODULE__, &put_in(&1, [:checkouts, id], checkout))
    checkout
  end

  def get_order(id), do: Agent.get(__MODULE__, &Map.get(&1.orders, id))

  def put_order(%{id: id} = order) do
    Agent.update(__MODULE__, &put_in(&1, [:orders, id], order))
    order
  end

  def get_idempotency(key), do: Agent.get(__MODULE__, &Map.get(&1.idempotency, key))

  def put_idempotency(key, record) do
    Agent.update(__MODULE__, &put_in(&1, [:idempotency, key], record))
  end
end
