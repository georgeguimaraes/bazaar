defmodule Bazaar.Store.ETSTest do
  use ExUnit.Case, async: true

  alias Bazaar.Store.ETS

  test "keeps checkouts, carts, orders and the cart index apart" do
    id = "id_#{System.unique_integer([:positive])}"

    assert ETS.put_checkout(%{id: id, status: :open}) == %{id: id, status: :open}
    assert ETS.put_cart(%{id: id, line_items: []}) == %{id: id, line_items: []}
    assert ETS.put_order(%{"id" => id}) == %{"id" => id}

    assert ETS.get_checkout(id).status == :open
    assert ETS.get_cart(id).line_items == []
    assert ETS.get_order(id) == %{"id" => id}

    assert ETS.checkout_for_cart(id) == nil
    assert ETS.put_checkout_for_cart(id, "chk") == :ok
    assert ETS.checkout_for_cart(id) == "chk"

    assert ETS.delete_cart(id) == :ok
    assert ETS.get_cart(id) == nil
    assert ETS.get_checkout("missing") == nil
  end
end
