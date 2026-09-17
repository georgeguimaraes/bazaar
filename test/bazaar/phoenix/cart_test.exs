defmodule Bazaar.Phoenix.CartTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Bazaar.Phoenix.Controller

  defmodule Handler do
    use Bazaar.Handler

    @impl true
    def capabilities, do: [:checkout, :cart]

    @items %{"roses" => %{item: %{"title" => "Roses", "price" => 3500}, stock: nil}}

    defp build(state), do: Bazaar.Cart.build(state, item: &Map.get(@items, &1))

    @impl true
    def create_cart(%{"line_items" => []}, _conn), do: {:error, :empty_cart}
    def create_cart(params, _conn), do: {:ok, params |> Bazaar.Cart.new() |> build()}

    @impl true
    def get_cart("missing", _conn), do: {:error, :not_found}
    def get_cart(id, _conn), do: {:ok, build(%{Bazaar.Cart.new(%{}) | id: id})}

    @impl true
    def update_cart(id, params, _conn),
      do: {:ok, build(%{Bazaar.Cart.new(params) | id: id})}

    @impl true
    def cancel_cart(id, _conn), do: {:ok, build(%{Bazaar.Cart.new(%{}) | id: id})}
  end

  defmodule WithCart do
    use Phoenix.Router
    use Bazaar.Phoenix.Router

    bazaar_routes("/", Handler)
  end

  defmodule WithoutCart do
    use Phoenix.Router
    use Bazaar.Phoenix.Router

    bazaar_routes("/", Handler, only: [:checkout])
  end

  test "mounts the four cart routes only with the capability" do
    routes =
      for route <- WithCart.__routes__(), route.path =~ "carts", do: {route.verb, route.path}

    assert routes == [
             {:post, "/carts"},
             {:get, "/carts/:id"},
             {:put, "/carts/:id"},
             {:post, "/carts/:id/cancel"}
           ]

    refute Enum.any?(WithoutCart.__routes__(), &(&1.path =~ "carts"))
  end

  defp call(action, method, path, params) do
    method
    |> conn(path, params)
    |> assign(:bazaar_handler, Handler)
    |> then(&apply(Controller, action, [&1, params]))
    |> then(&{&1.status, JSON.decode!(&1.resp_body)})
  end

  test "creates at 201, reads, updates and cancels at 200 with valid carts, 404 and 422 otherwise" do
    roses = %{"line_items" => [%{"id" => "li_1", "item" => %{"id" => "roses"}, "quantity" => 2}]}

    assert {201, created} = call(:create_cart, :post, "/carts", roses)
    assert {:ok, _} = Bazaar.Validator.validate(created, :cart)
    assert [%{"totals" => [%{"amount" => 7000}, _]}] = created["line_items"]

    assert {200, got} = call(:get_cart, :get, "/carts/c1", %{"id" => "c1"})
    assert got["id"] == "c1"

    assert {200, updated} = call(:update_cart, :put, "/carts/c1", Map.put(roses, "id", "c1"))
    assert {:ok, _} = Bazaar.Validator.validate(updated, :cart)
    assert length(updated["line_items"]) == 1

    assert {200, %{"id" => "c1"}} = call(:cancel_cart, :post, "/carts/c1/cancel", %{"id" => "c1"})

    assert {404, %{"messages" => [%{"code" => "not_found"}]}} =
             call(:get_cart, :get, "/carts/missing", %{"id" => "missing"})

    assert {422, %{"messages" => [%{"code" => "empty_cart"}]}} =
             call(:create_cart, :post, "/carts", %{"line_items" => []})
  end
end
