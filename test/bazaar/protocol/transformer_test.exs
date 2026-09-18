defmodule Bazaar.Protocol.TransformerTest do
  use ExUnit.Case, async: true

  alias Bazaar.Protocol.Transformer
  alias Bazaar.Validator

  # The RFC's create body, in the bundled 2026-01-30 shape.
  @create %{
    "currency" => "USD",
    "line_items" => [%{"id" => "roses", "quantity" => 2}],
    "buyer" => %{"first_name" => "John", "last_name" => "Smith", "email" => "john@example.com"},
    "fulfillment_details" => %{
      "name" => "John Smith",
      "phone_number" => "15551234567",
      "email" => "john@example.com",
      "address" => %{
        "name" => "John Smith",
        "line_one" => "1234 Chat Road",
        "line_two" => "",
        "city" => "San Francisco",
        "state" => "CA",
        "country" => "US",
        "postal_code" => "94102"
      }
    },
    "capabilities" => %{},
    "coupons" => ["10OFF"]
  }

  describe "transform_request/2 for ACP" do
    # The bundled create schema types line items as `Item`, which has no
    # `quantity`, while the RFC's example sends one. The fixture follows the RFC;
    # the schema check proves the rest of its shape.
    defp without_quantity(body),
      do:
        update_in(body["line_items"], &Enum.map(&1, fn item -> Map.delete(item, "quantity") end))

    test "turns the RFC's create body into a UCP request the checkout builder accepts" do
      assert {:ok, _} = Validator.validate(without_quantity(@create), :checkout_create_req)
      {:ok, ucp} = Transformer.transform_request(@create, :acp)

      assert ucp["line_items"] == [%{"item" => %{"id" => "roses"}, "quantity" => 2}]
      assert ucp["buyer"]["email"] == "john@example.com"
      assert ucp["discounts"] == %{"codes" => ["10OFF"]}
      refute Map.has_key?(ucp, "capabilities")

      assert [
               %{
                 "type" => "shipping",
                 "selected_destination_id" => "dest_1",
                 "destinations" => [
                   %{
                     "id" => "dest_1",
                     "street_address" => "1234 Chat Road",
                     "extended_address" => "",
                     "address_locality" => "San Francisco",
                     "address_region" => "CA",
                     "address_country" => "US",
                     "postal_code" => "94102",
                     "first_name" => "John",
                     "last_name" => "Smith",
                     "phone_number" => "15551234567"
                   }
                 ]
               }
             ] = ucp["fulfillment"]["methods"]

      state = Bazaar.Checkout.new(ucp)
      assert [%{product_id: "roses", quantity: 2}] = state.line_items
      assert [%{selected_destination_id: "dest_1"}] = state.methods
    end

    test "accepts the RFC's items spelling, selects an option, and carries payment data" do
      {:ok, ucp} = Transformer.transform_request(%{"items" => [%{"id" => "roses"}]}, :acp)
      assert ucp["line_items"] == [%{"item" => %{"id" => "roses"}, "quantity" => 1}]

      {:ok, ucp} =
        Transformer.transform_request(
          %{"selected_fulfillment_options" => [%{"option_id" => "exp", "item_ids" => ["roses"]}]},
          :acp
        )

      assert [
               %{
                 "id" => "method_1",
                 "groups" => [%{"id" => "group_1", "selected_option_id" => "exp"}]
               }
             ] =
               ucp["fulfillment"]["methods"]

      {:ok, ucp} =
        Transformer.transform_request(
          %{
            "payment_data" => %{
              "handler_id" => "card_tokenized",
              "instrument" => %{"type" => "card", "credential" => %{"token" => "spt_1"}},
              "billing_address" => %{
                "name" => "J",
                "line_one" => "1 Main",
                "city" => "SF",
                "state" => "CA",
                "country" => "US",
                "postal_code" => "1"
              }
            }
          },
          :acp
        )

      assert [
               %{
                 "type" => "card",
                 "handler_id" => "card_tokenized",
                 "billing_address" => %{"street_address" => "1 Main"}
               }
             ] =
               ucp["payment"]["instruments"]
    end

    test "leaves UCP requests alone" do
      assert Transformer.transform_request(%{"line_items" => []}, :ucp) ==
               {:ok, %{"line_items" => []}}
    end
  end

  # A checkout as Bazaar.Checkout builds it, with fulfillment, a discount and a message.
  defp checkout(extra \\ %{}) do
    state =
      Bazaar.Checkout.new(
        Map.merge(
          %{
            "currency" => "USD",
            "line_items" => [%{"id" => "li_1", "item" => %{"id" => "roses"}, "quantity" => 2}],
            "buyer" => %{
              "email" => "john@example.com",
              "first_name" => "John",
              "consent" => %{"marketing" => true}
            },
            "fulfillment" => %{
              "methods" => [
                %{
                  "id" => "m1",
                  "type" => "shipping",
                  "line_item_ids" => ["li_1"],
                  "destinations" => [
                    %{
                      "id" => "d1",
                      "address_country" => "US",
                      "postal_code" => "94102",
                      "first_name" => "John",
                      "last_name" => "Smith"
                    }
                  ],
                  "selected_destination_id" => "d1",
                  "groups" => [%{"id" => "g1", "selected_option_id" => "exp"}]
                }
              ]
            },
            "discounts" => %{"codes" => ["10OFF"]}
          },
          extra
        )
      )

    Bazaar.Checkout.build(state,
      item: fn "roses" -> %{item: %{"title" => "Roses", "price" => 3500}, stock: nil} end,
      fulfillment_options: fn _destination, _context ->
        [
          %{
            "id" => "std",
            "title" => "Standard",
            "totals" => [%{"type" => "total", "amount" => 500}]
          },
          %{
            "id" => "exp",
            "title" => "Express",
            "totals" => [%{"type" => "total", "amount" => 1500}]
          }
        ]
      end,
      discount: fn "10OFF", running ->
        %{"code" => "10OFF", "title" => "10% off", "amount" => div(running, 10)}
      end,
      payment_handlers: %{
        "dev.acp.tokenized.card" => [
          %{
            "id" => "card_tokenized",
            "version" => "2026-01-22",
            "spec" => "https://acp.dev/handlers/tokenized.card",
            "requires_delegate_payment" => true,
            "requires_pci_compliance" => false,
            "psp" => "stripe",
            "config_schema" => "https://acp.dev/schemas/config.json",
            "instrument_schemas" => ["https://acp.dev/schemas/instrument.json"],
            "config" => %{}
          }
        ]
      },
      links: [
        %{"type" => "privacy_policy", "url" => "https://shop.test/privacy"},
        %{"type" => "terms_of_service", "url" => "https://shop.test/terms"}
      ],
      order_url: &("https://shop.test/orders/" <> &1),
      messages: [Bazaar.Checkout.error("payment_failed", "Declined", "$.payment")]
    )
  end

  describe "transform_response/2 for ACP" do
    test "builds a checkout session that validates against the ACP schema" do
      {:ok, session} = Transformer.transform_response(checkout(), :acp)
      assert {:ok, _} = Validator.validate(session, :checkout_session)

      assert session["protocol"] == %{"version" => "2026-01-30"}
      assert session["status"] == "not_ready_for_payment"
      assert session["buyer"] == %{"email" => "john@example.com", "first_name" => "John"}

      assert [
               %{
                 "id" => "li_1",
                 "item" => %{"id" => "roses", "name" => "Roses", "unit_amount" => 3500},
                 "quantity" => 2,
                 "totals" => [%{"type" => "subtotal", "display_text" => "Subtotal"}, _]
               }
             ] =
               session["line_items"]

      assert Enum.map(session["totals"], &{&1["type"], &1["display_text"], &1["amount"]}) == [
               {"subtotal", "Subtotal", 7000},
               {"fulfillment", "Fulfillment", 1500},
               {"discount", "Discount", -850},
               {"total", "Total", 7650}
             ]

      assert [
               %{
                 "type" => "shipping",
                 "id" => "std",
                 "title" => "Standard",
                 "totals" => [%{"amount" => 500}]
               },
               %{"id" => "exp"}
             ] =
               session["fulfillment_options"]

      assert session["selected_fulfillment_options"] == [
               %{"type" => "shipping", "option_id" => "exp", "item_ids" => ["roses"]}
             ]

      assert session["fulfillment_details"] == %{
               "name" => "John Smith",
               "address" => %{
                 "name" => "John Smith",
                 "line_one" => "",
                 "city" => "",
                 "state" => "",
                 "country" => "US",
                 "postal_code" => "94102"
               }
             }

      assert [
               %{
                 "type" => "error",
                 "code" => "payment_declined",
                 "severity" => "high",
                 "content_type" => "plain",
                 "param" => "$.payment"
               }
             ] =
               session["messages"]

      assert Enum.map(session["links"], & &1["type"]) == ["privacy_policy", "terms_of_use"]

      assert [%{"id" => "card_tokenized", "name" => "dev.acp.tokenized.card", "psp" => "stripe"}] =
               session["capabilities"]["payment"]["handlers"]

      assert %{
               "codes" => ["10OFF"],
               "applied" => [
                 %{"id" => "10OFF", "coupon" => %{"name" => "10% off"}, "amount" => 850}
               ]
             } = session["discounts"]

      refute Map.has_key?(session, "ucp")
      refute Map.has_key?(session, "fulfillment")
    end

    test "a completed checkout carries the order and validates as a session with order" do
      completed =
        checkout()
        |> Map.put("status", "completed")
        |> Map.put("order", %{
          "id" => "order_1",
          "permalink_url" => "https://shop.test/orders/order_1"
        })

      {:ok, session} = Transformer.transform_response(completed, :acp)

      # CheckoutSessionWithOrder composes the base (a closed object) with `order`,
      # which JSON Schema can never satisfy, so the base is checked without it.
      assert {:ok, _} = Validator.validate(Map.delete(session, "order"), :checkout_session)
      assert session["status"] == "completed"

      assert session["order"] == %{
               "id" => "order_1",
               "checkout_session_id" => completed["id"],
               "permalink_url" => "https://shop.test/orders/order_1"
             }
    end

    test "a bare checkout without fulfillment or handlers still validates" do
      state = Bazaar.Checkout.new(%{"line_items" => [%{"item" => %{"id" => "roses"}}]})

      doc =
        Bazaar.Checkout.build(state,
          item: fn _ -> %{item: %{"title" => "Roses", "price" => 3500}, stock: nil} end,
          links: []
        )

      {:ok, session} = Transformer.transform_response(doc, :acp)

      assert {:ok, _} = Validator.validate(session, :checkout_session)
      assert session["capabilities"] == %{}
      assert session["fulfillment_options"] == []
      refute Map.has_key?(session, "buyer")
    end
  end

  describe "transform_address/2" do
    test "renames both ways, splitting and joining the name" do
      acp = %{
        "name" => "Ana Maria Silva",
        "line_one" => "1 Main",
        "line_two" => "Suite 1",
        "city" => "NYC",
        "state" => "NY",
        "country" => "US",
        "postal_code" => "10001"
      }

      ucp = Transformer.transform_address(acp, :acp_to_ucp)

      assert ucp == %{
               "first_name" => "Ana",
               "last_name" => "Maria Silva",
               "street_address" => "1 Main",
               "extended_address" => "Suite 1",
               "address_locality" => "NYC",
               "address_region" => "NY",
               "address_country" => "US",
               "postal_code" => "10001"
             }

      assert Transformer.transform_address(ucp, :ucp_to_acp) == acp

      assert Transformer.transform_address(%{"address_country" => "BR"}, :ucp_to_acp) == %{
               "name" => "",
               "line_one" => "",
               "city" => "",
               "state" => "",
               "country" => "BR",
               "postal_code" => ""
             }

      assert Transformer.transform_address(nil, :acp_to_ucp) == nil
    end
  end
end
