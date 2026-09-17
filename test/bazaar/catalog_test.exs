defmodule Bazaar.CatalogTest do
  use ExUnit.Case, async: true

  alias Bazaar.Catalog

  defp price(amount), do: %{"amount" => amount, "currency" => "USD"}

  defp variant(id, amount, extra \\ %{}) do
    Map.merge(
      %{"id" => id, "title" => id, "description" => %{"plain" => id}, "price" => price(amount)},
      extra
    )
  end

  defp product(id, variants, extra) do
    amounts = Enum.map(variants, & &1["price"]["amount"])

    Map.merge(
      %{
        "id" => id,
        "title" => id,
        "description" => %{"plain" => id},
        "price_range" => %{"min" => price(Enum.min(amounts)), "max" => price(Enum.max(amounts))},
        "variants" => variants
      },
      extra
    )
  end

  defp roses,
    do: product("roses", [variant("roses", 3500)], %{"categories" => [%{"value" => "bouquets"}]})

  defp pot,
    do:
      product("pot", [variant("pot", 1500, %{"sku" => "POT-1"})], %{
        "categories" => [%{"value" => "pots"}]
      })

  defp tulips,
    do:
      product("tulips", [variant("tulips-s", 2000), variant("tulips-l", 4000)], %{
        "categories" => [%{"value" => "bouquets"}]
      })

  defp products, do: [roses(), pot(), tulips()]

  describe "filter/2" do
    test "categories are OR within the list and unknown keys are ignored" do
      assert Catalog.filter(products(), %{"categories" => ["pots"]}) == [pot()]

      assert Catalog.filter(products(), %{"categories" => ["pots", "bouquets"], "color" => "red"}) ==
               products()

      assert Catalog.filter(products(), nil) == products()
    end

    test "price drops variants out of range and products left with none" do
      assert [%{"id" => "tulips", "variants" => [%{"id" => "tulips-s"}]}] =
               Catalog.filter(products(), %{"price" => %{"min" => 1600, "max" => 3000}})

      assert Catalog.filter(products(), %{"price" => %{"max" => 100}}) == []
    end
  end

  describe "paginate/2" do
    test "defaults to ten and says when there is no next page" do
      assert {page, %{"has_next_page" => false, "total_count" => 3} = pagination} =
               Catalog.paginate(products(), nil)

      assert length(page) == 3
      refute Map.has_key?(pagination, "cursor")
    end

    test "walks the pages through the cursor" do
      first_page = [roses(), pot()]

      assert {^first_page, %{"has_next_page" => true, "cursor" => cursor}} =
               Catalog.paginate(products(), %{"limit" => 2})

      assert {[%{"id" => "tulips"}], %{"has_next_page" => false}} =
               Catalog.paginate(products(), %{"limit" => 2, "cursor" => cursor})

      assert {^first_page, _} =
               Catalog.paginate(products(), %{"limit" => 2, "cursor" => "junk"})
    end
  end

  describe "lookup/2" do
    test "correlates variant ids, skus and product ids, and reports what nothing matched" do
      assert {[roses, pot, tulips], ["nope"]} =
               Catalog.lookup(products(), ["roses", "POT-1", "tulips", "tulips-l", "nope"])

      # The single variant shares the product's id: one exact match, not a featured one too.
      assert [%{"inputs" => [%{"id" => "roses", "match" => "exact"}]}] = roses["variants"]
      assert [%{"inputs" => [%{"id" => "POT-1", "match" => "exact"}]}] = pot["variants"]

      assert [
               %{"id" => "tulips-s", "inputs" => [%{"id" => "tulips", "match" => "featured"}]},
               %{"id" => "tulips-l", "inputs" => [%{"id" => "tulips-l", "match" => "exact"}]}
             ] = tulips["variants"]
    end

    test "find/2 resolves product and variant ids" do
      assert Catalog.find(products(), "tulips-l") == tulips()
      assert Catalog.find(products(), "pot") == pot()
      assert Catalog.find(products(), "nope") == nil
    end
  end

  describe "detail_product/3" do
    defp shirt do
      product(
        "shirt",
        [
          variant("shirt-red-s", 1000, %{
            "options" => [
              %{"name" => "Color", "label" => "Red"},
              %{"name" => "Size", "label" => "S"}
            ]
          }),
          variant("shirt-red-l", 1000, %{
            "options" => [
              %{"name" => "Color", "label" => "Red"},
              %{"name" => "Size", "label" => "L"}
            ],
            "availability" => %{"available" => false}
          }),
          variant("shirt-blue-s", 1000, %{
            "options" => [
              %{"name" => "Color", "label" => "Blue"},
              %{"name" => "Size", "label" => "S"}
            ]
          })
        ],
        %{
          "options" => [
            %{"name" => "Color", "values" => [%{"label" => "Red"}, %{"label" => "Blue"}]},
            %{"name" => "Size", "values" => [%{"label" => "S"}, %{"label" => "L"}]}
          ]
        }
      )
    end

    test "signals which values exist and are purchasable next to the selection" do
      detail = Catalog.detail_product(shirt(), [%{"name" => "Color", "label" => "Red"}])

      assert [%{"name" => "Color", "values" => colors}, %{"name" => "Size", "values" => sizes}] =
               detail["options"]

      assert [%{"label" => "Red", "exists" => true, "available" => true}, %{"label" => "Blue"}] =
               colors

      # Red exists in L but is sold out; Blue never comes in L.
      assert [
               %{"label" => "S", "exists" => true, "available" => true},
               %{"label" => "L", "exists" => true, "available" => false}
             ] = sizes

      assert detail["selected"] == [%{"name" => "Color", "label" => "Red"}]
      assert hd(detail["variants"])["id"] == "shirt-red-s"

      blue = Catalog.detail_product(shirt(), [%{"name" => "Color", "label" => "Blue"}])
      assert [_, %{"label" => "L", "exists" => false, "available" => false}] = sizes(blue)
      assert hd(blue["variants"])["id"] == "shirt-blue-s"
    end

    test "relaxes an impossible selection by preference and leaves optionless products alone" do
      impossible = [%{"name" => "Color", "label" => "Blue"}, %{"name" => "Size", "label" => "L"}]

      by_preference = Catalog.detail_product(shirt(), impossible, preferences: ["Size", "Color"])
      assert by_preference["selected"] == [%{"name" => "Size", "label" => "L"}]
      assert hd(by_preference["variants"])["id"] == "shirt-red-l"

      by_order = Catalog.detail_product(shirt(), impossible)
      assert by_order["selected"] == [%{"name" => "Color", "label" => "Blue"}]

      assert Catalog.detail_product(roses(), []) == roses()
    end

    defp sizes(detail), do: Enum.find(detail["options"], &(&1["name"] == "Size"))["values"]
  end

  test "envelope/2 names the capability that answered and keeps a handler's own" do
    assert %{"ucp" => %{"version" => version, "capabilities" => capabilities}} =
             Catalog.envelope(%{"products" => []}, :search)

    assert capabilities == %{"dev.ucp.shopping.catalog.search" => [%{"version" => version}]}

    assert %{"ucp" => %{"capabilities" => %{"dev.ucp.shopping.catalog.lookup" => _}}} =
             Catalog.envelope(%{"product" => %{}}, :lookup)

    own = %{"ucp" => %{"version" => "x"}, "products" => []}
    assert Catalog.envelope(own, :search) == own
  end
end
