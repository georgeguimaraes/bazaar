defmodule Bazaar.CheckoutTest do
  use ExUnit.Case, async: true

  alias Bazaar.Checkout

  describe "currency" do
    test "converts between major and minor units" do
      assert Checkout.to_minor_units(19.99) == 1999
      assert Checkout.to_minor_units(19.995) == 2000
      assert Checkout.to_minor_units(20) == 2000
      assert Checkout.to_minor_units(Decimal.new("100.50")) == 10_050
      assert Checkout.to_major_units(1999) == 19.99
    end
  end

  # A two-product shop: roses (stock 3, 3500) and a sold-out pot (1500).
  @items %{
    "roses" => %{item: %{"title" => "Roses", "price" => 3500}, stock: 3},
    "pot" => %{item: %{"title" => "Pot", "price" => 1500}, stock: 0},
    "card" => %{item: %{"title" => "Card", "price" => 200}, stock: nil}
  }

  @stored [
    %{
      "id" => "addr_1",
      "street_address" => "1 Main St",
      "address_locality" => "Springfield",
      "address_region" => "IL",
      "postal_code" => "62704",
      "address_country" => "US"
    }
  ]

  @rates [
    %{"id" => "std", "title" => "Standard", "totals" => [%{"type" => "total", "amount" => 500}]},
    %{"id" => "exp", "title" => "Express", "totals" => [%{"type" => "total", "amount" => 1500}]}
  ]

  defp stored_addresses(%{"email" => "known@example.com"}), do: @stored
  defp stored_addresses(_buyer), do: nil

  defp discount("10OFF", running),
    do: %{"code" => "10OFF", "title" => "10%", "amount" => div(running, 10)}

  defp discount("FIVE", running),
    do: %{"code" => "FIVE", "title" => "$5", "amount" => min(500, running)}

  defp discount(_code, _running), do: nil

  defp new(params), do: Checkout.new(params, stored_addresses: &stored_addresses/1)

  defp update(state, params),
    do: Checkout.apply_update(state, params, stored_addresses: &stored_addresses/1)

  defp build(state, opts \\ []) do
    doc =
      Checkout.build(
        state,
        [
          item: &Map.get(@items, &1),
          fulfillment_options: fn _destination, _context -> @rates end,
          discount: &discount/2,
          payment_handlers: %{"dev.example.pay" => [%{"id" => "pay", "version" => "2026-08-25"}]},
          links: [%{"type" => "privacy_policy", "url" => "https://shop.test/privacy"}],
          order_url: &("https://shop.test/orders/" <> &1)
        ] ++ opts
      )

    assert {:ok, _} = Bazaar.Validator.validate(doc, :checkout)
    doc
  end

  defp roses(quantity \\ 1),
    do: %{
      "line_items" => [%{"id" => "li_1", "item" => %{"id" => "roses"}, "quantity" => quantity}]
    }

  defp shipping(extra \\ %{}) do
    %{
      "fulfillment" => %{
        "methods" => [
          Map.merge(
            %{
              "id" => "m1",
              "type" => "shipping",
              "line_item_ids" => ["li_1"],
              "destinations" => [%{"id" => "d1", "country" => "US", "postal_code" => "00000"}],
              "selected_destination_id" => "d1"
            },
            extra
          )
        ]
      }
    }
  end

  defp total(doc, type), do: Enum.find(doc["totals"], &(&1["type"] == type))["amount"]

  describe "line items" do
    test "prices from the business, drops unknown and sold-out items, clamps to stock" do
      doc =
        %{
          "line_items" => [
            %{"id" => "li_1", "item" => %{"id" => "roses", "price" => 1}, "quantity" => 5},
            %{"item" => %{"id" => "pot"}},
            %{"item" => %{"id" => "nope"}},
            %{"item" => %{"id" => "card"}, "quantity" => 1000}
          ]
        }
        |> new()
        |> build()

      assert [
               %{"id" => "li_1", "item" => %{"id" => "roses", "price" => 3500}, "quantity" => 3},
               %{"id" => "li_4", "quantity" => 1000}
             ] = doc["line_items"]

      assert [
               %{"type" => "warning", "code" => "quantity_adjusted", "path" => "$.line_items[0]"},
               %{"type" => "error", "code" => "out_of_stock", "path" => "$.line_items[1]"},
               %{"type" => "error", "code" => "not_found", "path" => "$.line_items[2]"}
             ] = doc["messages"]

      assert total(doc, "subtotal") == 3 * 3500 + 1000 * 200
      assert doc["status"] == "incomplete"
    end
  end

  describe "totals and discounts" do
    test "stack codes on the running total, allocate, and drop unknown ones" do
      doc =
        roses()
        |> Map.merge(shipping(%{"groups" => [%{"id" => "g1", "selected_option_id" => "exp"}]}))
        |> Map.put("discounts", %{
          "codes" => ["10OFF", "NOPE", "FIVE"],
          "applied" => [%{"code" => "NOPE"}]
        })
        |> new()
        |> build()

      # 3500 + 1500 shipping = 5000; 10% = 500; then $5 on 4500
      assert [
               %{
                 "code" => "10OFF",
                 "amount" => 500,
                 "allocations" => [%{"path" => "$.totals", "amount" => 500}]
               },
               %{"code" => "FIVE", "amount" => 500}
             ] = doc["discounts"]["applied"]

      assert doc["discounts"]["codes"] == ["10OFF", "NOPE", "FIVE"]

      assert Enum.map(doc["totals"], &{&1["type"], &1["amount"]}) == [
               {"subtotal", 3500},
               {"fulfillment", 1500},
               {"discount", -500},
               {"discount", -500},
               {"total", 4000}
             ]

      assert doc["status"] == "ready_for_complete"
    end

    test "omits discounts and fulfillment entries when there is nothing to say" do
      doc = roses() |> new() |> build()
      refute Map.has_key?(doc, "discounts")
      assert Enum.map(doc["totals"], & &1["type"]) == ["subtotal", "total"]
    end
  end

  describe "fulfillment" do
    test "offers options once a destination is selected and reports readiness" do
      unselected =
        roses() |> Map.merge(shipping(%{"selected_destination_id" => nil})) |> new() |> build()

      [%{"groups" => [group], "destinations" => [destination]}] =
        unselected["fulfillment"]["methods"]

      refute Map.has_key?(group, "options")

      assert destination == %{
               "id" => "d1",
               "type" => "shipping_address",
               "address_country" => "US",
               "postal_code" => "00000"
             }

      # The recipient fields UCP's postal address defines survive normalization.
      named =
        roses()
        |> Map.merge(
          shipping(%{
            "destinations" => [
              %{
                "id" => "d1",
                "country" => "US",
                "postal_code" => "1",
                "first_name" => "Ana",
                "phone_number" => "555"
              }
            ]
          })
        )
        |> new()

      assert [%{destinations: [%{"first_name" => "Ana", "phone_number" => "555"}]}] =
               named.methods

      assert unselected["status"] == "incomplete"
      refute Checkout.fulfillment_ready?(unselected)

      selected = roses() |> Map.merge(shipping()) |> new() |> build()
      [%{"groups" => [group]}] = selected["fulfillment"]["methods"]
      assert Enum.map(group["options"], & &1["id"]) == ["std", "exp"]
      assert selected["status"] == "incomplete"

      ready =
        roses()
        |> Map.merge(shipping(%{"groups" => [%{"id" => "g1", "selected_option_id" => "std"}]}))
        |> new()
        |> build()

      assert total(ready, "fulfillment") == 500
      assert Checkout.fulfillment_ready?(ready)
    end

    test "carries destinations, groups and line item ids across updates" do
      state =
        roses()
        |> Map.merge(shipping(%{"groups" => [%{"id" => "g1", "selected_option_id" => "std"}]}))
        |> new()

      # The platform resends only the method id; everything earlier stays.
      updated = update(state, %{"fulfillment" => %{"methods" => [%{"id" => "m1"}]}})
      [method] = updated.methods
      assert method.line_item_ids == ["li_1"]
      assert [%{"id" => "d1"}] = method.destinations
      assert method.selected_destination_id == "d1"
      assert [%{id: "g1", selected_option_id: "std"}] = method.groups

      # A method with two line items and no groups gets one consolidating group.
      two =
        %{
          "line_items" => [
            %{"id" => "a", "item" => %{"id" => "roses"}},
            %{"id" => "b", "item" => %{"id" => "card"}}
          ]
        }
        |> Map.put("fulfillment", %{"methods" => [%{"type" => "shipping"}]})
        |> new()

      assert [%{id: "method_1", groups: [%{id: "group_1", line_item_ids: ["a", "b"]}]}] =
               two.methods
    end

    test "injects a known buyer's stored addresses and keeps their ids on resubmission" do
      state = roses() |> Map.put("buyer", %{"email" => "known@example.com"}) |> new()
      injected = update(state, %{"fulfillment" => %{"methods" => [%{"id" => "m1"}]}})

      assert [%{destinations: [%{"id" => "addr_1", "type" => "shipping_address"}]}] =
               injected.methods

      # The same address sent back under a client id resolves to the stored one.
      resubmitted =
        update(injected, %{
          "fulfillment" => %{
            "methods" => [
              %{
                "id" => "m1",
                "destinations" => [
                  %{
                    "id" => "client_1",
                    "street" => "1 Main St",
                    "city" => "Springfield",
                    "state" => "IL",
                    "postal_code" => "62704",
                    "country" => "US"
                  }
                ],
                "selected_destination_id" => "client_1"
              }
            ]
          }
        })

      assert [%{destinations: [%{"id" => "addr_1"}], selected_destination_id: "addr_1"}] =
               resubmitted.methods

      unknown = roses() |> Map.put("buyer", %{"email" => "new@example.com"}) |> new()

      assert [%{destinations: []}] =
               update(unknown, %{"fulfillment" => %{"methods" => [%{}]}}).methods
    end
  end

  describe "lifecycle and envelope" do
    test "reports canceled and completed with the order reference" do
      state = roses() |> new()
      assert build(%{state | status: :canceled})["status"] == "canceled"

      done = build(%{state | status: :completed, order_id: "order_1"})
      assert done["status"] == "completed"

      assert done["order"] == %{
               "id" => "order_1",
               "permalink_url" => "https://shop.test/orders/order_1"
             }

      assert_raise ArgumentError, ~r/order_url/, fn ->
        Checkout.build(%{state | order_id: "order_1"}, item: &Map.get(@items, &1))
      end
    end

    test "carries the envelope, payment handlers, instruments and extra messages" do
      doc =
        roses()
        |> Map.put("payment", %{
          "instruments" => [%{"id" => "card_1", "handler_id" => "pay", "type" => "card"}]
        })
        |> new()
        |> build(messages: [Checkout.error("payment_failed", "Declined", "$.payment")])

      assert %{
               "version" => "2026-08-25",
               "capabilities" => %{"dev.ucp.shopping.checkout" => _},
               "payment_handlers" => %{"dev.example.pay" => _}
             } =
               doc["ucp"]

      assert [%{"id" => "card_1"}] = doc["payment"]["instruments"]

      assert [
               %{
                 "code" => "payment_failed",
                 "severity" => "requires_buyer_input",
                 "path" => "$.payment"
               }
             ] = doc["messages"]

      assert doc["status"] == "incomplete"
      assert doc["id"] =~ ~r/^chk_/
    end

    test "answers consent in the platform's dialect" do
      legacy =
        roses()
        |> Map.put("buyer", %{"email" => "c@example.com", "consent" => %{"marketing" => true}})
        |> new()

      assert %{"dev.ucp.consent.marketing" => %{"granted" => true}} = legacy.buyer["consent"]
      assert build(legacy)["buyer"]["consent"] == %{"marketing" => true}

      purposes = %{
        "dev.ucp.consent.marketing" => %{
          "granted" => false,
          "source" => "platform",
          "description" => "Promos"
        }
      }

      modern =
        roses() |> Map.put("buyer", %{"email" => "c@example.com", "consent" => purposes}) |> new()

      assert build(modern)["buyer"]["consent"] == purposes
    end
  end
end
