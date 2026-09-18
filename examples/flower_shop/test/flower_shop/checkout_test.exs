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
  end

  describe "loyalty and payment terms" do
    test "answers the program's claim, verified for a known customer, and flags unknown claims" do
      known =
        roses(2)
        |> Map.merge(%{
          "buyer" => %{"email" => "john.doe@example.com"},
          "context" => %{"eligibility" => ["com.flowershop.rewards"]}
        })
        |> create()
        |> Checkout.build()

      assert {:ok, _} = Bazaar.Validator.validate(known, :checkout_loyalty)
      membership = known["loyalty"]["com.flowershop.rewards"]
      assert membership["provisional"] == false
      assert membership["display_id"] =~ ~r/^\*\*\*\*/
      assert get_in(membership, ["rewards", Access.at(0), "earning_forecast", "amount"]) == 70

      stranger =
        roses()
        |> Map.merge(%{
          "buyer" => %{"email" => "new@example.com"},
          "context" => %{"eligibility" => ["com.flowershop.rewards", "com.other.club"]}
        })
        |> create()
        |> Checkout.build()

      assert stranger["loyalty"]["com.flowershop.rewards"]["provisional"] == true
      refute Map.has_key?(stranger["loyalty"]["com.flowershop.rewards"], "display_id")

      assert [%{"code" => "eligibility_invalid", "severity" => "recoverable"}] =
               stranger["messages"]
    end

    test "offers two payment terms, pay now by default, and carries the chosen one onto the order" do
      state = roses() |> create()
      doc = Checkout.build(state)
      assert {:ok, _} = Bazaar.Validator.validate(doc, :checkout_payment_terms)
      assert doc["payment"]["selected_term_id"] == "pay_now"

      chosen = Checkout.apply_update(state, %{"payment" => %{"selected_term_id" => "half_now"}})
      doc = Checkout.build(chosen)

      assert [%{"amount" => 1750}, %{"amount" => 1750, "type" => "on_delivery"}] =
               Enum.find(doc["payment"]["terms"], &(&1["id"] == "half_now"))["schedules"]

      order = Bazaar.Order.from_checkout(doc, "order_1", "http://shop.test/orders/order_1")
      assert {:ok, _} = Bazaar.Validator.validate(order, :order_payment_terms)
      assert order["payment"]["accepted_term"]["id"] == "half_now"
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
