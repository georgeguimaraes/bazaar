defmodule FlowerShopWeb.UncoveredCapabilitiesTest do
  @moduledoc """
  The capabilities the official conformance suite doesn't exercise, driven
  through the endpoint the way a platform reaches them: the plug pipeline
  (version negotiation, idempotency, signature verification, response
  signing), the router and the controller. Every response is validated
  against the bundled 2026-08-25 schemas.
  """

  use ExUnit.Case, async: true

  import Plug.Conn
  import Phoenix.ConnTest
  import Bazaar.Test, only: [assert_valid: 2]

  @endpoint FlowerShopWeb.Endpoint

  # The headers the conformance suite's platform sends on every call.
  defp request(method, path, body \\ nil) do
    conn =
      build_conn()
      |> put_req_header(
        "ucp-agent",
        ~s(profile="http://localhost:8285/profiles/shopping-agent.json")
      )
      |> put_req_header("idempotency-key", "e2e-#{System.unique_integer([:positive])}")
      |> put_req_header("content-type", "application/json")

    conn =
      case method do
        :get -> get(conn, path)
        :post -> post(conn, path, Jason.encode!(body || %{}))
        :put -> put(conn, path, Jason.encode!(body || %{}))
      end

    # Successful responses leave signed, with the key the profile publishes.
    if conn.status in 200..299, do: assert([_] = get_resp_header(conn, "signature"))
    {conn.status, json_response(conn, conn.status)}
  end

  describe "catalog" do
    test "search, lookup and get product answer spec documents" do
      {200, search} =
        request(:post, "/catalog/search", %{
          "query" => "roses",
          "filters" => %{"categories" => ["bouquets"]}
        })

      assert_valid(search, :catalog_search_response)
      assert [%{"id" => "bouquet_roses"}] = search["products"]

      {200, lookup} =
        request(:post, "/catalog/lookup", %{"ids" => ["orchid_white", "pink_wumpus"]})

      assert_valid(lookup, :catalog_lookup_response)

      assert [%{"id" => "orchid_white", "variants" => [%{"inputs" => [%{"match" => "exact"}]}]}] =
               lookup["products"]

      assert [%{"code" => "not_found"}] = lookup["messages"]

      {200, product} = request(:post, "/catalog/product", %{"id" => "gardenias"})
      assert_valid(product, :catalog_product_response)

      assert get_in(product, ["product", "variants", Access.at(0), "availability", "available"]) ==
               false

      {200, missing} = request(:post, "/catalog/product", %{"id" => "pink_wumpus"})
      assert_valid(missing, :error_response)
    end
  end

  describe "carts" do
    test "create, update, convert to a checkout once, cancel" do
      {201, cart} =
        request(:post, "/carts", %{
          "line_items" => [%{"item" => %{"id" => "bouquet_tulips"}, "quantity" => 2}],
          "buyer" => %{"email" => "john.doe@example.com"}
        })

      assert_valid(cart, :cart)
      id = cart["id"]

      {200, updated} =
        request(:put, "/carts/#{id}", %{"line_items" => [%{"item" => %{"id" => "pot_ceramic"}}]})

      assert_valid(updated, :cart)
      assert [%{"item" => %{"id" => "pot_ceramic"}}] = updated["line_items"]

      {201, checkout} =
        request(:post, "/checkout-sessions", %{
          "cart_id" => id,
          "line_items" => [%{"item" => %{"id" => "gardenias"}}]
        })

      assert_valid(checkout, :checkout)
      assert [%{"item" => %{"id" => "pot_ceramic"}}] = checkout["line_items"]

      {201, again} = request(:post, "/checkout-sessions", %{"cart_id" => id})
      assert again["id"] == checkout["id"]

      {200, canceled} = request(:post, "/carts/#{id}/cancel")
      assert_valid(canceled, :cart)
      assert {404, _} = request(:get, "/carts/#{id}")
    end
  end

  describe "locations" do
    test "search by distance, hours and amenities, and a batch-limited lookup" do
      {200, near} =
        request(:post, "/locations/search", %{
          "distance" => %{
            "center" => %{"latitude" => 39.8, "longitude" => -89.65},
            "max" => 5_000
          },
          "filters" => %{
            "hours" => %{"open_at" => "2026-06-10T20:30:00Z"},
            "amenities" => ["dev.ucp.amenity.parking"]
          }
        })

      assert_valid(near, :location_search_response)
      assert [%{"id" => "loc_springfield"}] = near["locations"]

      # The shop answers serves and items itself: nothing within its radius of the origin.
      {200, far} =
        request(:post, "/locations/search", %{
          "serves" => %{"point" => %{"latitude" => 0, "longitude" => 0}},
          "filters" => %{"items" => ["bouquet_roses"]}
        })

      assert_valid(far, :location_search_response)
      assert far["locations"] == []

      ids = ["loc_metropolis" | Enum.map(1..11, &"loc_#{&1}")]
      {200, lookup} = request(:post, "/locations/lookup", %{"ids" => ids})
      assert_valid(lookup, :location_lookup_response)

      assert [%{"id" => "loc_metropolis", "inputs" => [%{"id" => "loc_metropolis"}]}] =
               lookup["locations"]

      assert "batch_limit_applied" in Enum.map(lookup["messages"], & &1["code"])
    end
  end

  describe "loyalty and payment terms" do
    test "a claim is answered, a term is selected, and the order carries it" do
      {201, checkout} =
        request(:post, "/checkout-sessions", %{
          "currency" => "USD",
          "line_items" => [
            %{"id" => "li_1", "item" => %{"id" => "bouquet_roses"}, "quantity" => 2}
          ],
          "buyer" => %{"email" => "john.doe@example.com"},
          "context" => %{"eligibility" => ["com.flowershop.rewards"]},
          "fulfillment" => %{
            "methods" => [
              %{
                "id" => "m1",
                "type" => "shipping",
                "line_item_ids" => ["li_1"],
                "destinations" => [
                  %{"id" => "d1", "address_country" => "US", "postal_code" => "62704"}
                ],
                "selected_destination_id" => "d1",
                "groups" => [%{"id" => "g1", "selected_option_id" => "std-ship"}]
              }
            ]
          }
        })

      assert_valid(checkout, :checkout_loyalty)
      assert_valid(checkout, :checkout_payment_terms)
      assert checkout["loyalty"]["com.flowershop.rewards"]["provisional"] == false
      assert checkout["payment"]["selected_term_id"] == "pay_now"
      id = checkout["id"]

      {200, chosen} =
        request(:put, "/checkout-sessions/#{id}", %{
          "payment" => %{"selected_term_id" => "half_now"}
        })

      assert chosen["payment"]["selected_term_id"] == "half_now"

      {200, completed} =
        request(:post, "/checkout-sessions/#{id}/complete", %{
          "payment" => %{
            "instruments" => [
              %{"id" => "card_1", "handler_id" => "mock_payment_handler", "type" => "card"}
            ]
          }
        })

      assert completed["status"] == "completed"

      {200, order} = request(:get, "/orders/#{completed["order"]["id"]}")
      assert_valid(order, :order_payment_terms)

      assert [%{"amount" => 3500}, %{"amount" => 3500}] =
               order["payment"]["accepted_term"]["schedules"]
    end
  end

  describe "pickup" do
    test "a store is offered, chosen, priced free, and reaches the order's expectation" do
      {201, offered} =
        request(:post, "/checkout-sessions", %{
          "currency" => "USD",
          "line_items" => [%{"id" => "li_1", "item" => %{"id" => "bouquet_sunflowers"}}],
          "context" => %{"location" => "loc_springfield"}
        })

      assert_valid(offered, :checkout)

      assert [
               %{
                 "type" => "pickup",
                 "selected_destination_id" => "loc_springfield",
                 "destinations" => [%{"type" => "business_location"}]
               }
             ] = offered["fulfillment"]["methods"]

      id = offered["id"]

      {200, wrong} =
        request(:put, "/checkout-sessions/#{id}", %{
          "fulfillment" => %{
            "methods" => [%{"id" => "pickup", "selected_destination_id" => "loc_mars"}]
          }
        })

      assert [
               %{
                 "code" => "invalid",
                 "path" => "$.fulfillment.methods[0].selected_destination_id"
               }
             ] = wrong["messages"]

      {200, chosen} =
        request(:put, "/checkout-sessions/#{id}", %{
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

      assert chosen["status"] == "ready_for_complete"
      assert Enum.find(chosen["totals"], &(&1["type"] == "fulfillment"))["amount"] == 0

      {200, completed} =
        request(:post, "/checkout-sessions/#{id}/complete", %{
          "payment" => %{
            "instruments" => [
              %{"id" => "card_1", "handler_id" => "mock_payment_handler", "type" => "card"}
            ]
          }
        })

      {200, order} = request(:get, "/orders/#{completed["order"]["id"]}")
      assert_valid(order, :order)

      assert [
               %{
                 "method_type" => "pickup",
                 "destination" => %{"address_locality" => "Metropolis"}
               }
             ] = order["fulfillment"]["expectations"]
    end
  end
end
