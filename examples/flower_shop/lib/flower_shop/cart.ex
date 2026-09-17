defmodule FlowerShop.Cart do
  @moduledoc """
  The flower shop's side of `Bazaar.Cart`: the same items and discounts as
  its checkouts, and a `continue_url` back to the shop.
  """

  alias Bazaar.Cart

  def new(params, opts),
    do: params |> Cart.new() |> Map.put(:base_url, Keyword.fetch!(opts, :base_url))

  def apply_update(state, params), do: Cart.apply_update(state, params)

  def build(state) do
    Cart.build(state,
      item: &FlowerShop.Checkout.item/1,
      discount: &FlowerShop.Checkout.discount/2,
      continue_url: state.base_url <> "/carts/" <> state.id
    )
  end
end
