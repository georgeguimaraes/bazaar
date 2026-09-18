defmodule Bazaar.Cart do
  @moduledoc """
  Carts: estimated pricing before checkout, with no payment, fulfillment or
  status. A cart's state is a `Bazaar.Checkout` state (the platform sends the
  same line items, buyer and context), so the same update rules and the same
  pricing apply, and a cart converts to a checkout with
  `Bazaar.Checkout.from_cart/3`.

      state = Bazaar.Cart.new(params)
      Bazaar.Cart.build(state, item: &Shop.item/1, continue_url: "https://shop.example/carts/" <> state.id)

  Updates are full replacements in the spec, which `line_items` already are
  in `Bazaar.Checkout.apply_update/3`.
  """

  alias Bazaar.Checkout

  @cart_fields ~w(id line_items currency totals messages buyer context links loyalty)

  defdelegate new(params, opts \\ []), to: Checkout
  defdelegate apply_update(state, params, opts \\ []), to: Checkout

  @doc """
  The cart document for a state. Takes `Bazaar.Checkout.build/2`'s `:item`,
  `:discount`, `:links`, `:messages` and `:loyalty`, plus `:continue_url`
  and `:expires_at` (RFC 3339) for the cart itself.
  """
  def build(state, opts) do
    version = Bazaar.DiscoveryProfile.version()

    %{state | methods: nil, instruments: []}
    |> Checkout.build(Keyword.take(opts, [:item, :discount, :links, :messages, :loyalty]))
    |> Map.take(@cart_fields)
    |> Map.reject(fn {key, value} -> key == "links" and value == [] end)
    |> Map.put("ucp", %{
      "version" => version,
      "capabilities" => %{"dev.ucp.shopping.cart" => [%{"version" => version}]}
    })
    |> put_unless_nil("continue_url", Keyword.get(opts, :continue_url))
    |> put_unless_nil("expires_at", Keyword.get(opts, :expires_at))
  end

  defp put_unless_nil(doc, _key, nil), do: doc
  defp put_unless_nil(doc, key, value), do: Map.put(doc, key, value)
end
