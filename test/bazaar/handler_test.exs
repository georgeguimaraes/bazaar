defmodule Bazaar.HandlerTest do
  use ExUnit.Case, async: true

  defmodule Plain do
    use Bazaar.Handler, shop: Bazaar.TestShop, store: Bazaar.Store.ETS
  end

  defmodule Custom do
    use Bazaar.Handler, shop: Bazaar.TestShop, store: Bazaar.Store.ETS

    @impl true
    def capabilities, do: [:checkout, :orders, :identity]

    @impl true
    def business_profile, do: %{"name" => "Custom Store", "website" => "https://custom.example"}

    # A default replaced, still able to lean on Defaults for the rest.
    @impl true
    def get_checkout("special", _conn), do: {:ok, %{"id" => "special"}}
    def get_checkout(id, conn), do: Bazaar.Handler.Defaults.get_checkout(__MODULE__, id, conn)

    @impl true
    def link_identity(%{"token" => token}, _conn), do: {:ok, %{"linked" => token}}
    def link_identity(_params, _conn), do: {:error, :invalid_params}
  end

  test "use Bazaar.Handler defines discovery defaults and every capability callback" do
    assert Plain.capabilities() == [:checkout]
    assert Plain.business_profile()["name"] == "My Store"
    assert Bazaar.Handler in (Plain.__info__(:attributes)[:behaviour] || [])
    assert Plain.__bazaar__(:shop) == Bazaar.TestShop
    assert Plain.__bazaar__(:store) == Bazaar.Store.ETS

    for {name, arity} <- [
          create_checkout: 2,
          get_checkout: 2,
          update_checkout: 3,
          complete_checkout: 3,
          cancel_checkout: 2,
          create_cart: 2,
          get_cart: 2,
          update_cart: 3,
          cancel_cart: 2,
          get_order: 2,
          update_order: 3,
          cancel_order: 2,
          search_products: 2,
          lookup_products: 2,
          get_product: 2,
          search_locations: 2,
          lookup_locations: 2
        ] do
      assert function_exported?(Plain, name, arity), "#{name}/#{arity} should be defined"
    end

    refute function_exported?(Plain, :link_identity, 2)
  end

  test "callbacks and discovery can be overridden, and defaults called from an override" do
    assert Custom.capabilities() == [:checkout, :orders, :identity]
    assert Custom.business_profile()["website"] == "https://custom.example"
    assert Custom.get_checkout("special", nil) == {:ok, %{"id" => "special"}}
    assert Custom.get_checkout("missing", nil) == {:error, :not_found}
    assert Custom.link_identity(%{"token" => "t"}, nil) == {:ok, %{"linked" => "t"}}
    assert Custom.link_identity(%{}, nil) == {:error, :invalid_params}
  end

  test "a shop and a store are both required" do
    assert_raise ArgumentError, ~r/needs a shop and a store/, fn ->
      defmodule Bare do
        use Bazaar.Handler
      end
    end

    assert_raise ArgumentError, ~r/needs a shop and a store/, fn ->
      defmodule ShopOnly do
        use Bazaar.Handler, shop: Bazaar.TestShop
      end
    end
  end
end
