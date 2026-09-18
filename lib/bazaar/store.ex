defmodule Bazaar.Store do
  @moduledoc """
  Where a handler keeps its checkouts, carts and orders, as a behaviour.
  `use Bazaar.Handler, shop: ..., store: MyApp.Store` reads and writes
  through it.

  Checkouts and carts are `Bazaar.Checkout` states (maps with atom keys);
  orders are the UCP order documents. `Bazaar.Store.ETS` is the in-memory
  store for development and a single node; a production store is a few
  functions over your database.
  """

  @type id :: String.t()
  @type state :: map()
  @type order :: map()

  @callback get_checkout(id()) :: state() | nil
  @callback put_checkout(state()) :: state()

  @callback get_cart(id()) :: state() | nil
  @callback put_cart(state()) :: state()
  @callback delete_cart(id()) :: :ok

  @callback get_order(id()) :: order() | nil
  @callback put_order(order()) :: order()

  @doc "The checkout a cart was converted into, so a repeat conversion answers the same one."
  @callback checkout_for_cart(cart_id :: id()) :: id() | nil
  @callback put_checkout_for_cart(cart_id :: id(), checkout_id :: id()) :: :ok
end
