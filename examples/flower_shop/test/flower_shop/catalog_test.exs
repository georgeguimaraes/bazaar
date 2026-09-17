defmodule FlowerShop.CatalogTest do
  use ExUnit.Case, async: true

  alias Bazaar.Validator
  alias FlowerShop.Handler

  defp search(params) do
    {:ok, doc} = Handler.search_products(params, nil)

    assert {:ok, _} =
             Validator.validate(Bazaar.Catalog.envelope(doc, :search), :catalog_search_response)

    doc
  end

  defp ids(doc), do: Enum.map(doc["products"], & &1["id"])

  test "finds products by query, category and price" do
    assert ids(search(%{"query" => "roses"})) == ["bouquet_roses"]
    assert ids(search(%{"query" => "CERAMIC"})) == ["pot_ceramic"]

    assert ids(search(%{"filters" => %{"categories" => ["plants", "pots"]}})) ==
             ["orchid_white", "pot_ceramic"]

    assert ids(search(%{"filters" => %{"price" => %{"max" => 2000}}})) ==
             ["gardenias", "pot_ceramic"]
  end

  test "pages the whole catalog two at a time and marks what is sold out" do
    first = search(%{"pagination" => %{"limit" => 2}})

    assert %{"has_next_page" => true, "total_count" => 6, "cursor" => cursor} =
             first["pagination"]

    assert length(first["products"]) == 2

    rest = search(%{"pagination" => %{"limit" => 4, "cursor" => cursor}})
    assert rest["pagination"]["has_next_page"] == false
    assert ids(first) ++ ids(rest) == Enum.sort(ids(search(%{})))

    gardenias = Enum.find(rest["products"] ++ first["products"], &(&1["id"] == "gardenias"))
    assert [%{"availability" => %{"available" => false}}] = gardenias["variants"]
  end

  test "looks up known ids and reports the unknown ones" do
    {:ok, doc} = Handler.lookup_products(%{"ids" => ["bouquet_tulips", "pink_wumpus"]}, nil)

    assert {:ok, _} =
             Validator.validate(Bazaar.Catalog.envelope(doc, :lookup), :catalog_lookup_response)

    assert [%{"id" => "bouquet_tulips", "variants" => [%{"inputs" => [input]}]}] = doc["products"]
    assert input == %{"id" => "bouquet_tulips", "match" => "exact"}
    assert [%{"type" => "info", "code" => "not_found"}] = doc["messages"]
  end

  test "gets one product and misses gracefully" do
    {:ok, doc} = Handler.get_product(%{"id" => "orchid_white"}, nil)

    assert {:ok, _} =
             Validator.validate(Bazaar.Catalog.envelope(doc, :lookup), :catalog_product_response)

    assert doc["product"]["title"] == "White Orchid"
    assert Handler.get_product(%{"id" => "pink_wumpus"}, nil) == {:error, :not_found}
  end
end
