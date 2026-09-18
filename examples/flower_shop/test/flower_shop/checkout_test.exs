defmodule FlowerShop.CheckoutTest do
  use ExUnit.Case, async: true

  import Bazaar.Test

  alias FlowerShop.Handler

  defp roses(quantity \\ 1) do
    %{
      "currency" => "USD",
      "line_items" => [
        %{"id" => "li_1", "item" => %{"id" => "bouquet_roses"}, "quantity" => quantity}
      ]
    }
  end

  defp shipping_to(country, extra \\ %{}) do
    %{
      "fulfillment" => %{
        "methods" => [
          Map.merge(
            %{
              "id" => "m1",
              "type" => "shipping",
              "line_item_ids" => ["li_1"],
              "destinations" => [
                %{"id" => "d1", "address_country" => country, "postal_code" => "00000"}
              ],
              "selected_destination_id" => "d1"
            },
            extra
          )
        ]
      }
    }
  end

  defp create(params) do
    {201, doc} = request(Handler, :create_checkout, params)
    assert_valid(doc, :checkout)
  end

  defp update(id, params) do
    {200, doc} = request(Handler, :update_checkout, Map.put(params, "id", id))
    assert_valid(doc, :checkout)
  end

  defp total(doc, type), do: Enum.find(doc["totals"], &(&1["type"] == type))["amount"]

  test "prices from the catalog and ignores the client price" do
    doc =
      create(%{
        "line_items" => [%{"item" => %{"id" => "pot_ceramic", "price" => 1}, "quantity" => 2}]
      })

    assert [%{"item" => %{"price" => 1500}, "totals" => [%{"amount" => 3000}, _]}] =
             doc["line_items"]

    assert total(doc, "total") == 3000
  end

  test "stacks discount codes on the running total, echoes canonical codes, drops unknown ones" do
    doc = create(Map.put(roses(), "discounts", %{"codes" => ["10off", "WELCOME20", "NOPE"]}))

    assert [%{"code" => "10OFF", "amount" => 350}, %{"code" => "WELCOME20", "amount" => 630}] =
             doc["discounts"]["applied"]

    assert total(doc, "total") == 3500 - 350 - 630
  end

  test "offers the right shipping rates per country, free standard with roses" do
    us = create(Map.merge(roses(), shipping_to("US")))
    [%{"groups" => [group]}] = us["fulfillment"]["methods"]

    assert [
             %{
               "id" => "std-ship",
               "title" => "Standard Shipping (Free)",
               "totals" => [%{"amount" => 0}]
             },
             %{"id" => "exp-ship-us"}
           ] = group["options"]

    ca =
      create(
        Map.merge(
          %{"line_items" => [%{"id" => "li_1", "item" => %{"id" => "pot_ceramic"}}]},
          shipping_to("CA")
        )
      )

    [%{"groups" => [group]}] = ca["fulfillment"]["methods"]

    assert [%{"id" => "std-ship", "totals" => [%{"amount" => 500}]}, %{"id" => "exp-ship-intl"}] =
             group["options"]
  end

  test "offers pickup at both stores and prices it free once one is chosen" do
    offered = create(roses())

    assert [
             %{
               "type" => "pickup",
               "destinations" => [%{"id" => "loc_springfield"}, %{"id" => "loc_metropolis"}]
             }
           ] = offered["fulfillment"]["methods"]

    chosen =
      update(offered["id"], %{
        "fulfillment" => %{
          "methods" => [
            %{
              "id" => "pickup",
              "selected_destination_id" => "loc_metropolis",
              "groups" => [%{"id" => "group_1", "selected_option_id" => "in_store"}]
            }
          ]
        }
      })

    assert [
             %{
               "selected_destination_id" => "loc_metropolis",
               "destinations" => [%{"name" => "Flower Shop Metropolis"}]
             }
           ] = chosen["fulfillment"]["methods"]

    assert total(chosen, "fulfillment") == 0
    assert chosen["status"] == "ready_for_complete"
  end

  test "injects a known customer's stored addresses into a method without any" do
    doc =
      create(
        Map.merge(roses(), %{
          "buyer" => %{"email" => "john.doe@example.com"},
          "fulfillment" => %{"methods" => [%{"id" => "m1", "type" => "shipping"}]}
        })
      )

    assert [%{"destinations" => [%{"id" => "addr_1"}, %{"id" => "addr_2"}]}] =
             doc["fulfillment"]["methods"]
  end

  test "answers the loyalty claim, verified for a known customer, provisional otherwise" do
    known =
      create(
        Map.merge(roses(2), %{
          "buyer" => %{"email" => "john.doe@example.com"},
          "context" => %{"eligibility" => ["com.flowershop.rewards"]}
        })
      )

    assert_valid(known, :checkout_loyalty)
    membership = known["loyalty"]["com.flowershop.rewards"]
    assert membership["provisional"] == false
    assert membership["display_id"] =~ ~r/^\*\*\*\*/
    assert get_in(membership, ["rewards", Access.at(0), "earning_forecast", "amount"]) == 70

    stranger =
      create(
        Map.merge(roses(), %{
          "buyer" => %{"email" => "new@example.com"},
          "context" => %{"eligibility" => ["com.flowershop.rewards", "com.other.club"]}
        })
      )

    assert stranger["loyalty"]["com.flowershop.rewards"]["provisional"] == true
    refute Map.has_key?(stranger["loyalty"], "com.other.club")
  end

  test "offers two payment terms, pay now by default, and completes with the chosen one on the order" do
    doc =
      create(
        Map.merge(
          roses(),
          shipping_to("US", %{"groups" => [%{"id" => "g1", "selected_option_id" => "std-ship"}]})
        )
      )

    assert_valid(doc, :checkout_payment_terms)
    assert doc["payment"]["selected_term_id"] == "pay_now"

    chosen = update(doc["id"], %{"payment" => %{"selected_term_id" => "half_now"}})

    assert [%{"amount" => 1750}, %{"amount" => 1750, "type" => "on_delivery"}] =
             Enum.find(chosen["payment"]["terms"], &(&1["id"] == "half_now"))["schedules"]

    {200, completed} =
      request(Handler, :complete_checkout, %{
        "id" => doc["id"],
        "payment" => %{
          "instruments" => [
            %{"id" => "card_1", "handler_id" => "mock_payment_handler", "type" => "card"}
          ]
        }
      })

    assert completed["status"] == "completed"
    {200, order} = request(Handler, :get_order, %{"id" => completed["order"]["id"]})
    assert_valid(order, :order_payment_terms)
    assert order["payment"]["accepted_term"]["id"] == "half_now"
  end

  test "a declined instrument keeps the checkout open with a payment_failed message" do
    doc =
      create(
        Map.merge(
          roses(),
          shipping_to("US", %{"groups" => [%{"id" => "g1", "selected_option_id" => "std-ship"}]})
        )
      )

    {200, declined} =
      request(Handler, :complete_checkout, %{
        "id" => doc["id"],
        "payment" => %{
          "instruments" => [
            %{
              "id" => "i1",
              "handler_id" => "mock_payment_handler",
              "type" => "card",
              "credential" => %{"token" => "fail_token"}
            }
          ]
        }
      })

    assert [%{"code" => "payment_failed"}] = declined["messages"]
    refute Map.has_key?(declined, "order")
  end
end
