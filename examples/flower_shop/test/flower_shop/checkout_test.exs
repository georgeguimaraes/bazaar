defmodule FlowerShop.CheckoutTest do
  use ExUnit.Case, async: true

  alias FlowerShop.Checkout

  @base_url "http://shop.test"

  defp create(params), do: Checkout.new(params, base_url: @base_url)

  defp roses(quantity \\ 1) do
    %{
      "line_items" => [
        %{"id" => "li_1", "item" => %{"id" => "bouquet_roses"}, "quantity" => quantity}
      ]
    }
  end

  defp shipping_to(country, extra \\ %{}) do
    %{
      "fulfillment" => %{
        "methods" => [
          %{
            "id" => "m1",
            "type" => "shipping",
            "line_item_ids" => ["li_1"],
            "destinations" => [
              %{"id" => "d1", "address_country" => country, "postal_code" => "00000"}
            ],
            "selected_destination_id" => "d1"
          }
          |> Map.merge(extra)
        ]
      }
    }
  end

  defp total(doc, type), do: Enum.find(doc["totals"], &(&1["type"] == type))["amount"]

  describe "pricing" do
    test "prices from the catalog and ignores the client price" do
      doc =
        %{"line_items" => [%{"item" => %{"id" => "pot_ceramic", "price" => 1}, "quantity" => 2}]}
        |> create()
        |> Checkout.build()

      assert [%{"item" => %{"price" => 1500}, "totals" => [%{"amount" => 3000}, _]}] =
               doc["line_items"]

      assert total(doc, "subtotal") == 3000
      assert total(doc, "total") == 3000
    end

    test "drops unknown and sold-out items with an error message" do
      doc =
        %{
          "line_items" => [
            %{"item" => %{"id" => "pink_wumpus"}},
            %{"item" => %{"id" => "gardenias"}}
          ]
        }
        |> create()
        |> Checkout.build()

      assert doc["line_items"] == []
      assert ["not_found", "out_of_stock"] = Enum.map(doc["messages"], & &1["code"])
      assert doc["status"] == "ready_for_complete"
    end

    test "clamps quantity to stock with a warning" do
      doc = roses(10_001) |> create() |> Checkout.build()

      assert [%{"quantity" => 1000}] = doc["line_items"]
      assert [%{"type" => "warning", "code" => "quantity_adjusted"}] = doc["messages"]
    end
  end

  describe "discounts" do
    test "stack sequentially on the running total and echo canonical codes" do
      doc =
        roses()
        |> Map.put("discounts", %{"codes" => ["10off", "WELCOME20"]})
        |> create()
        |> Checkout.build()

      assert [%{"code" => "10OFF", "amount" => 350}, %{"code" => "WELCOME20", "amount" => 630}] =
               doc["discounts"]["applied"]

      assert total(doc, "total") == 3500 - 350 - 630
    end

    test "drop unknown codes and client-supplied applied entries" do
      doc =
        roses()
        |> Map.put("discounts", %{
          "codes" => ["NOPE", "FIXED500"],
          "applied" => [%{"code" => "NOPE", "amount" => 99_999}]
        })
        |> create()
        |> Checkout.build()

      assert [%{"code" => "FIXED500", "amount" => 500}] = doc["discounts"]["applied"]
      assert total(doc, "total") == 3000
    end
  end

  describe "fulfillment" do
    test "offers express US and free standard shipping to a US address with roses" do
      doc = roses() |> Map.merge(shipping_to("US")) |> create() |> Checkout.build()
      [%{"groups" => [group]}] = doc["fulfillment"]["methods"]

      assert Enum.map(group["options"], & &1["id"]) == ["std-ship", "exp-ship-us"]

      assert [%{"title" => "Standard Shipping (Free)", "totals" => [%{"amount" => 0}]} | _] =
               group["options"]
    end

    test "offers international express to a Canadian address at full price" do
      doc =
        %{"line_items" => [%{"id" => "li_1", "item" => %{"id" => "pot_ceramic"}}]}
        |> Map.merge(shipping_to("CA"))
        |> create()
        |> Checkout.build()

      [%{"groups" => [group]}] = doc["fulfillment"]["methods"]

      assert Enum.map(group["options"], & &1["id"]) == ["std-ship", "exp-ship-intl"]
      assert [%{"totals" => [%{"amount" => 500}]}, _] = group["options"]
    end

    test "adds the selected option to the total and reports readiness" do
      doc =
        roses()
        |> Map.merge(
          shipping_to("US", %{
            "groups" => [%{"id" => "g1", "selected_option_id" => "exp-ship-us"}]
          })
        )
        |> create()
        |> Checkout.build()

      assert total(doc, "fulfillment") == 1500
      assert total(doc, "total") == 5000
      assert Checkout.fulfillment_ready?(doc)
    end

    test "injects a known customer's stored addresses and keeps their ids on resubmission" do
      state = roses() |> Map.put("buyer", %{"email" => "john.doe@example.com"}) |> create()

      injected =
        Checkout.apply_update(state, %{
          "fulfillment" => %{"methods" => [%{"id" => "m1", "type" => "shipping"}]}
        })

      [%{destinations: destinations}] = injected.methods
      assert Enum.map(destinations, & &1["id"]) == ["addr_1", "addr_2"]

      resubmitted =
        Checkout.apply_update(injected, %{
          "fulfillment" => %{
            "methods" => [
              %{
                "id" => "m1",
                "destinations" => [hd(destinations) |> Map.put("id", "")],
                "selected_destination_id" => ""
              }
            ]
          }
        })

      assert [%{destinations: [%{"id" => "addr_1"}]}] = resubmitted.methods
    end
  end
end
