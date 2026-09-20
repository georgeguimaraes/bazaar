defmodule Bazaar.Store.EctoTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Bazaar.TestEctoStore, as: Store

  setup_all do
    dir = Path.join(System.tmp_dir!(), "bazaar_gen_store_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    # The migration the generator writes is the one the store runs on.
    capture_io(fn ->
      Mix.Tasks.Bazaar.Gen.Store.run(["--output-dir", dir, "--repo", "Bazaar.TestRepo"])
    end)

    [path] = Path.wildcard(Path.join(dir, "*_create_bazaar_store.exs"))
    [{migration, _}] = Code.compile_file(path)

    File.rm(Application.get_env(:bazaar, Bazaar.TestRepo)[:database])
    {:ok, _} = Bazaar.TestRepo.start_link()
    Ecto.Migrator.up(Bazaar.TestRepo, 1, migration, log: false)
    :ok
  end

  test "round-trips checkout states, carts, orders and the conversion index" do
    id = "chk_#{System.unique_integer([:positive])}"

    state =
      Bazaar.Checkout.new(%{
        "id" => id,
        "line_items" => [%{"item" => %{"id" => "roses"}, "quantity" => 2}],
        "buyer" => %{"email" => "a@b.c", "consent" => %{"marketing" => true}}
      })

    assert Store.put_checkout(state) == state
    assert Store.get_checkout(id) == state
    assert Store.get_checkout("missing") == nil

    updated = %{state | status: :canceled}
    Store.put_checkout(updated)
    assert Store.get_checkout(id).status == :canceled

    cart = Bazaar.Cart.new(%{"id" => "cart_" <> id, "line_items" => []})
    Store.put_cart(cart)
    assert Store.get_cart(cart.id) == cart
    assert Store.checkout_for_cart(cart.id) == nil
    assert Store.put_checkout_for_cart(cart.id, id) == :ok
    assert Store.checkout_for_cart(cart.id) == id
    assert Store.delete_cart(cart.id) == :ok
    assert Store.get_cart(cart.id) == nil
    # The index outlives the cart, so a repeat conversion still answers the checkout.
    assert Store.checkout_for_cart(cart.id) == id

    order = %{
      "id" => "order_" <> id,
      "checkout_id" => id,
      "totals" => [%{"type" => "total", "amount" => 7000}]
    }

    assert Store.put_order(order) == order
    assert Store.get_order(order["id"]) == order

    assert Store.put_order(Map.put(order, "adjustments", [%{"id" => "adj_1"}]))["adjustments"] ==
             [%{"id" => "adj_1"}]

    assert Store.get_order("missing") == nil
  end

  test "a handler on the repo never starts the ETS store" do
    defmodule EctoShop do
      use Bazaar.Shop

      @impl true
      def base_url, do: "https://shop.test"

      @impl true
      def item(_id), do: %{item: %{"title" => "Roses", "price" => 3500}, stock: nil}

      @impl true
      def http_client, do: nil
    end

    defmodule EctoHandler do
      use Bazaar.Handler, shop: EctoShop, store: Bazaar.TestEctoStore
    end

    # Whatever other tests did, the point is this handler doesn't need it.
    {:ok, checkout} =
      EctoHandler.create_checkout(%{"line_items" => [%{"item" => %{"id" => "r"}}]}, nil)

    assert {:ok, ^checkout} = EctoHandler.get_checkout(checkout["id"], nil)
    assert Bazaar.TestEctoStore.get_checkout(checkout["id"]).id == checkout["id"]
  end
end
