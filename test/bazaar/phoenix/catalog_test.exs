defmodule Bazaar.Phoenix.CatalogTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Bazaar.Phoenix.Controller

  defmodule Handler do
    use Bazaar.Handler

    @impl true
    def capabilities, do: [:checkout, :catalog]

    @products [
      %{
        "id" => "roses",
        "title" => "Roses",
        "description" => %{"plain" => "A dozen"},
        "price_range" => %{
          "min" => %{"amount" => 3500, "currency" => "USD"},
          "max" => %{"amount" => 3500, "currency" => "USD"}
        },
        "variants" => [
          %{
            "id" => "roses",
            "title" => "Roses",
            "description" => %{"plain" => "A dozen"},
            "price" => %{"amount" => 3500, "currency" => "USD"}
          }
        ]
      }
    ]

    @impl true
    def search_products(%{"query" => "boom"}, _conn), do: {:error, :search_down}

    def search_products(params, _conn) do
      {page, pagination} = Bazaar.Catalog.paginate(@products, params["pagination"])
      {:ok, %{"products" => page, "pagination" => pagination}}
    end

    @impl true
    def lookup_products(%{"ids" => ids}, _conn) do
      {products, _unknown} = Bazaar.Catalog.lookup(@products, ids)
      {:ok, %{"products" => products}}
    end

    @impl true
    def get_product(%{"id" => id} = params, _conn) do
      case Bazaar.Catalog.find(@products, id) do
        nil ->
          {:error, :not_found}

        product ->
          {:ok, %{"product" => Bazaar.Catalog.detail_product(product, params["selected"])}}
      end
    end
  end

  defmodule Router do
    use Phoenix.Router
    use Bazaar.Phoenix.Router

    bazaar_routes("/", Handler)
  end

  test "mounts the spec's three catalog POSTs" do
    routes =
      for route <- Router.__routes__(), route.path =~ "catalog", do: {route.verb, route.path}

    assert routes == [
             {:post, "/catalog/search"},
             {:post, "/catalog/lookup"},
             {:post, "/catalog/product"}
           ]
  end

  defp call(action, params) do
    :post
    |> conn("/catalog/#{action}", params)
    |> assign(:bazaar_handler, Handler)
    |> then(&apply(Controller, action, [&1, params]))
    |> then(&{&1.status, JSON.decode!(&1.resp_body)})
  end

  test "renders spec-valid search, lookup and product documents with the ucp envelope" do
    assert {200, search} = call(:search_products, %{"query" => "roses"})
    assert {:ok, _} = Bazaar.Validator.validate(search, :catalog_search_response)
    assert %{"dev.ucp.shopping.catalog.search" => _} = search["ucp"]["capabilities"]

    assert {200, lookup} = call(:lookup_products, %{"ids" => ["roses"]})
    assert {:ok, _} = Bazaar.Validator.validate(lookup, :catalog_lookup_response)
    assert %{"dev.ucp.shopping.catalog.lookup" => _} = lookup["ucp"]["capabilities"]

    assert {200, product} = call(:get_product, %{"id" => "roses"})
    assert {:ok, _} = Bazaar.Validator.validate(product, :catalog_product_response)
    assert product["product"]["id"] == "roses"
  end

  test "an unknown product is the error document at 200, other failures 422" do
    assert {200, %{"ucp" => %{"status" => "error"}, "messages" => [%{"code" => "not_found"}]}} =
             call(:get_product, %{"id" => "nope"})

    assert {422, %{"messages" => [%{"code" => "missing_id"}]}} = call(:get_product, %{})

    assert {422, %{"messages" => [%{"code" => "missing_ids"}]}} =
             call(:lookup_products, %{"ids" => []})

    assert {422, %{"messages" => [%{"code" => "search_down"}]}} =
             call(:search_products, %{"query" => "boom"})
  end
end
