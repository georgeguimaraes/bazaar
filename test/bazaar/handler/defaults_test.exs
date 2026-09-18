defmodule Bazaar.Handler.DefaultsTest do
  use ExUnit.Case, async: true

  import Bazaar.Test

  # The shop records what order_placed hears, so the hook can be asserted.
  defmodule Shop do
    use Bazaar.Shop

    defdelegate base_url, to: Bazaar.TestShop
    defdelegate item(id), to: Bazaar.TestShop
    defdelegate fulfillment_options(destination, context), to: Bazaar.TestShop
    defdelegate products, to: Bazaar.TestShop
    defdelegate locations, to: Bazaar.TestShop

    @impl true
    def discount("10OFF", running),
      do: %{"code" => "10OFF", "title" => "Ten", "amount" => div(running, 10)}

    def discount(_code, _running), do: nil

    @impl true
    def authorize([%{"type" => "declined"}]), do: {:error, "Declined"}
    def authorize(_instruments), do: :ok

    @impl true
    def order_placed(order, conn), do: send(conn.assigns.test, {:order_placed, order["id"]})
  end

  defmodule Handler do
    use Bazaar.Handler, shop: Shop, store: Bazaar.Store.ETS

    @impl true
    def capabilities,
      do: [:checkout, :orders, :fulfillment, :discount, :cart, :catalog, :location]
  end

  defp req(action, params, opts \\ []),
    do: request(Handler, action, params, Keyword.merge([assigns: [test: self()]], opts))

  test "a checkout goes from create through update to an order, the shop hearing of it" do
    {201, created} =
      req(
        :create_checkout,
        checkout_request(%{
          "line_items" => [%{"id" => "li_1", "item" => %{"id" => "roses"}, "quantity" => 2}]
        })
      )

    assert_valid(created, :checkout)
    assert created["status"] == "incomplete"

    assert [%{"groups" => [%{"options" => [%{"id" => "std"}]}]}] =
             created["fulfillment"]["methods"]

    id = created["id"]

    {200, updated} =
      req(:update_checkout, %{
        "id" => id,
        "fulfillment" => %{
          "methods" => [
            %{"id" => "m1", "groups" => [%{"id" => "group_1", "selected_option_id" => "std"}]}
          ]
        },
        "discounts" => %{"codes" => ["10OFF"]}
      })

    assert_valid(updated, :checkout)
    assert updated["status"] == "ready_for_complete"
    assert Enum.find(updated["totals"], &(&1["type"] == "total"))["amount"] == 7000 + 500 - 750

    {200, declined} =
      req(:complete_checkout, %{
        "id" => id,
        "payment" => %{
          "instruments" => [%{"id" => "i1", "handler_id" => "h", "type" => "declined"}]
        }
      })

    assert [%{"code" => "payment_failed"}] = declined["messages"]
    refute_received {:order_placed, _}

    {200, completed} =
      req(:complete_checkout, %{
        "id" => id,
        "payment" => %{"instruments" => [%{"id" => "i2", "handler_id" => "h", "type" => "card"}]}
      })

    assert_valid(completed, :checkout)
    assert completed["status"] == "completed"
    order_id = completed["order"]["id"]
    assert_received {:order_placed, ^order_id}

    {200, order} = req(:get_order, %{"id" => order_id})
    assert_valid(order, :order)
    assert {422, _} = req(:update_checkout, %{"id" => id, "line_items" => []})
    assert {422, _} = req(:cancel_order, %{"id" => order_id})
    assert {404, _} = req(:get_checkout, %{"id" => "nope"})
  end

  test "complete refuses without a selected fulfillment when the handler advertises it" do
    {201, created} =
      req(
        :create_checkout,
        checkout_request(%{"line_items" => [%{"id" => "li_1", "item" => %{"id" => "roses"}}]})
      )

    {200, refused} =
      req(:complete_checkout, %{
        "id" => created["id"],
        "payment" => %{"instruments" => [%{"id" => "i1", "handler_id" => "h", "type" => "card"}]}
      })

    assert refused["status"] == "incomplete"
    assert [%{"code" => "missing", "path" => "$.fulfillment"}] = refused["messages"]
  end

  test "a cart converts to a checkout once" do
    {201, cart} = req(:create_cart, %{"line_items" => [%{"item" => %{"id" => "roses"}}]})
    assert_valid(cart, :cart)
    assert cart["continue_url"] == "https://shop.test/carts/" <> cart["id"]

    {201, checkout} =
      req(:create_checkout, %{
        "cart_id" => cart["id"],
        "line_items" => [%{"item" => %{"id" => "pot"}}]
      })

    assert [%{"item" => %{"id" => "roses"}}] = checkout["line_items"]
    {201, again} = req(:create_checkout, %{"cart_id" => cart["id"]})
    assert again["id"] == checkout["id"]
    assert {404, _} = req(:create_checkout, %{"cart_id" => "nope"})

    {200, _} = req(:cancel_cart, %{"id" => cart["id"]})
    assert {404, _} = req(:get_cart, %{"id" => cart["id"]})
  end

  test "catalog and locations answer from the shop's lists" do
    {200, search} = req(:search_products, %{"query" => "rose"})
    assert_valid(search, :catalog_search_response)
    assert [%{"id" => "roses"}] = search["products"]

    {200, product} = req(:get_product, %{"id" => "roses"})
    assert_valid(product, :catalog_product_response)

    {200, stores} =
      req(:search_locations, %{"filters" => %{"amenities" => ["dev.ucp.amenity.parking"]}})

    assert_valid(stores, :location_search_response)
    assert [%{"id" => "loc_1"}] = stores["locations"]

    # The shop answers no serves predicate, so the spec has the request rejected.
    assert {422, %{"messages" => [%{"code" => "unsupported_filter"}]}} =
             req(:search_locations, %{
               "serves" => %{"point" => %{"latitude" => 0, "longitude" => 0}}
             })
  end
end
