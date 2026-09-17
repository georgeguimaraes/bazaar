defmodule FlowerShop.CartTest do
  use ExUnit.Case, async: true

  import Plug.Test, only: [conn: 2]

  alias Bazaar.Validator
  alias FlowerShop.Handler

  defp valid(doc, schema) do
    assert {:ok, _} = Validator.validate(doc, schema)
    doc
  end

  @roses %{
    "line_items" => [%{"id" => "li_1", "item" => %{"id" => "bouquet_roses"}, "quantity" => 2}]
  }

  test "creates, replaces, cancels, and then the cart is gone" do
    {:ok, cart} =
      Handler.create_cart(Map.put(@roses, "buyer", %{"email" => "c@example.com"}), nil)

    valid(cart, :cart)
    assert [%{"totals" => [%{"amount" => 7000}, _]}] = cart["line_items"]
    assert cart["continue_url"] =~ "/carts/" <> cart["id"]

    {:ok, updated} =
      Handler.update_cart(
        cart["id"],
        %{"line_items" => [%{"item" => %{"id" => "pot_ceramic"}}]},
        nil
      )

    assert [%{"item" => %{"id" => "pot_ceramic"}}] = valid(updated, :cart)["line_items"]
    assert updated["buyer"]["email"] == "c@example.com"

    assert {:ok, %{"id" => id}} = Handler.cancel_cart(cart["id"], nil)
    assert id == cart["id"]
    assert Handler.get_cart(id, nil) == {:error, :not_found}
    assert Handler.update_cart(id, @roses, nil) == {:error, :not_found}
  end

  test "converts to a checkout once, from the cart's contents" do
    {:ok, cart} =
      Handler.create_cart(Map.put(@roses, "buyer", %{"email" => "john.doe@example.com"}), nil)

    payload = %{
      "cart_id" => cart["id"],
      "line_items" => [%{"item" => %{"id" => "gardenias"}}],
      "buyer" => %{"email" => "other@example.com"},
      "fulfillment" => %{"methods" => [%{"id" => "m1", "type" => "shipping"}]}
    }

    {:ok, checkout} = Handler.create_checkout(payload, conn(:post, "/"))
    valid(checkout, :checkout)
    assert [%{"item" => %{"id" => "bouquet_roses"}, "quantity" => 2}] = checkout["line_items"]
    assert checkout["buyer"]["email"] == "john.doe@example.com"
    # The known buyer's stored addresses reach the payload's method.
    assert [%{"destinations" => [%{"id" => "addr_1"}, _]}] = checkout["fulfillment"]["methods"]

    assert {:ok, %{"id" => same}} = Handler.create_checkout(payload, conn(:post, "/"))
    assert same == checkout["id"]

    assert Handler.create_checkout(%{"cart_id" => "nope"}, conn(:post, "/")) ==
             {:error, :not_found}
  end
end
