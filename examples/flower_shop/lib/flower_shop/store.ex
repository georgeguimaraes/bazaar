defmodule FlowerShop.Store do
  @moduledoc """
  In-memory `Bazaar.Store` on an Agent, plus the idempotency records and
  each order's webhook URL. All a demo merchant needs, and it keeps the
  example free of a database.
  """

  @behaviour Bazaar.Store

  use Agent

  def start_link(_opts) do
    Agent.start_link(
      fn ->
        %{
          carts: %{},
          checkout_for_cart: %{},
          checkouts: %{},
          orders: %{},
          webhook_urls: %{},
          idempotency: %{}
        }
      end,
      name: __MODULE__
    )
  end

  @impl Bazaar.Store
  def get_checkout(id), do: get(:checkouts, id)

  @impl Bazaar.Store
  def put_checkout(%{id: id} = checkout), do: put(:checkouts, id, checkout)

  @impl Bazaar.Store
  def get_cart(id), do: get(:carts, id)

  @impl Bazaar.Store
  def put_cart(%{id: id} = cart), do: put(:carts, id, cart)

  @impl Bazaar.Store
  def delete_cart(id),
    do: Agent.update(__MODULE__, &update_in(&1.carts, fn carts -> Map.delete(carts, id) end))

  @impl Bazaar.Store
  def get_order(id), do: get(:orders, id)

  @impl Bazaar.Store
  def put_order(%{"id" => id} = order), do: put(:orders, id, order)

  @impl Bazaar.Store
  def checkout_for_cart(cart_id), do: get(:checkout_for_cart, cart_id)

  @impl Bazaar.Store
  def put_checkout_for_cart(cart_id, checkout_id) do
    put(:checkout_for_cart, cart_id, checkout_id)
    :ok
  end

  @doc "Where an order's events are delivered, learned when it was placed."
  def get_webhook_url(order_id), do: get(:webhook_urls, order_id)
  def put_webhook_url(order_id, url), do: put(:webhook_urls, order_id, url)

  def get_idempotency(key), do: get(:idempotency, key)
  def put_idempotency(key, record), do: put(:idempotency, key, record)

  defp get(bucket, key), do: Agent.get(__MODULE__, &Map.get(Map.fetch!(&1, bucket), key))

  defp put(bucket, key, value) do
    Agent.update(__MODULE__, &put_in(&1, [bucket, key], value))
    value
  end
end
