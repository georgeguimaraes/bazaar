defmodule Bazaar.CartTest do
  use ExUnit.Case, async: true

  alias Bazaar.{Cart, Checkout}

  @items %{"roses" => %{item: %{"title" => "Roses", "price" => 3500}, stock: 3}}

  defp build(state, opts \\ []) do
    doc = Cart.build(state, [item: &Map.get(@items, &1)] ++ opts)
    assert {:ok, _} = Bazaar.Validator.validate(doc, :cart)
    doc
  end

  @params %{
    "line_items" => [
      %{"id" => "li_1", "item" => %{"id" => "roses"}, "quantity" => 5},
      %{"id" => "li_2", "item" => %{"id" => "nope"}}
    ],
    "buyer" => %{"email" => "c@example.com"},
    "context" => %{"country" => "US", "currency" => "USD"}
  }

  test "builds a priced cart with the cart envelope and nothing from checkout" do
    doc =
      @params
      |> Cart.new()
      |> build(continue_url: "https://shop.test/carts/c1", expires_at: "2026-09-18T00:00:00Z")

    assert %{"capabilities" => %{"dev.ucp.shopping.cart" => _}} = doc["ucp"]
    assert [%{"id" => "li_1", "quantity" => 3, "item" => %{"price" => 3500}}] = doc["line_items"]
    assert [%{"code" => "quantity_adjusted"}, %{"code" => "not_found"}] = doc["messages"]

    assert Enum.map(doc["totals"], &{&1["type"], &1["amount"]}) == [
             {"subtotal", 3 * 3500},
             {"total", 3 * 3500}
           ]

    assert doc["context"] == %{"country" => "US", "currency" => "USD"}
    assert doc["continue_url"] == "https://shop.test/carts/c1"

    assert Map.keys(doc) --
             ~w(buyer context continue_url currency expires_at id line_items messages totals ucp) ==
             []
  end

  test "an update replaces the line items" do
    state =
      @params
      |> Cart.new()
      |> Cart.apply_update(%{"line_items" => [%{"item" => %{"id" => "roses"}}]})

    assert [%{"id" => "li_1", "quantity" => 1}] = build(state)["line_items"]
  end

  test "converts to a checkout from the cart's contents, ignoring the payload's" do
    cart = Cart.new(@params)

    checkout =
      Checkout.from_cart(cart, %{
        "line_items" => [%{"item" => %{"id" => "other"}}],
        "buyer" => %{"email" => "other@example.com"},
        "context" => %{"country" => "CA"},
        "fulfillment" => %{"methods" => [%{"id" => "m1", "type" => "shipping"}]}
      })

    assert checkout.line_items == cart.line_items
    assert checkout.buyer == cart.buyer
    assert checkout.context == cart.context
    assert checkout.currency == cart.currency
    # The payload's method covers the cart's line items, not the payload's.
    assert [%{id: "m1", line_item_ids: ["li_1", "li_2"]}] = checkout.methods
    assert checkout.id != cart.id
  end
end
