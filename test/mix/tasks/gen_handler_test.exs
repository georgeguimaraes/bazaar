defmodule Mix.Tasks.Bazaar.Gen.HandlerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Bazaar.Validator

  @tmp Path.join(System.tmp_dir!(), "bazaar_gen_handler_#{System.unique_integer([:positive])}")

  setup_all do
    File.mkdir_p!(@tmp)
    on_exit(fn -> File.rm_rf!(@tmp) end)

    {output, _modules, source} =
      generate(
        "ScaffoldFull.Handler",
        ~w(--capabilities checkout,orders,fulfillment,discount,cart,catalog --name Blooms)
      )

    %{output: output, source: source}
  end

  # Generated at runtime, so the modules are named indirectly to keep the compiler quiet.
  defp full, do: Module.concat(["ScaffoldFull", "Handler"])
  defp default, do: Module.concat(["ScaffoldDefault", "Handler"])

  setup do
    start_supervised!(Module.concat(full(), "Store"))
    :ok
  end

  # Runs the generator and loads what it wrote, the way an app would compile it.
  defp generate(module, args) do
    dir = Path.join(@tmp, Macro.underscore(module))

    output =
      capture_io(fn ->
        Mix.Tasks.Bazaar.Gen.Handler.run([module, "--output-dir", dir | args])
      end)

    path = Path.join(dir, Macro.underscore(module))
    modules = Enum.flat_map([Path.join(path, "store.ex"), path <> ".ex"], &Code.compile_file/1)
    {output, Enum.map(modules, &elem(&1, 0)), File.read!(path <> ".ex")}
  end

  test "prints the wiring and generates a handler that answers on first boot", %{output: output} do
    assert output =~ ~s(bazaar_routes "/", ScaffoldFull.Handler)
    assert output =~ "ScaffoldFull.Handler.Store"
    assert output =~ "body_reader"

    handler = full()

    assert handler.capabilities() == [
             :checkout,
             :orders,
             :fulfillment,
             :discount,
             :cart,
             :catalog,
             :buyer_consent
           ]

    assert handler.business_profile()["name"] == "Blooms"

    assert {:ok, _} =
             Validator.validate(Bazaar.DiscoveryProfile.from_handler(handler), :profile)

    conn = Plug.Test.conn(:post, "/", %{})

    # Checkout for the sample product, through to an order.
    body = %{
      "currency" => "USD",
      "line_items" => [%{"id" => "li_1", "item" => %{"id" => "sample"}, "quantity" => 2}],
      "fulfillment" => %{
        "methods" => [
          %{
            "id" => "m1",
            "type" => "shipping",
            "line_item_ids" => ["li_1"],
            "destinations" => [%{"id" => "d1", "address_country" => "US", "postal_code" => "1"}],
            "selected_destination_id" => "d1",
            "groups" => [%{"id" => "g1", "selected_option_id" => "standard"}]
          }
        ]
      }
    }

    {:ok, checkout} = handler.create_checkout(body, conn)
    assert {:ok, _} = Validator.validate(checkout, :checkout)
    assert checkout["status"] == "ready_for_complete"
    assert Enum.find(checkout["totals"], &(&1["type"] == "total"))["amount"] == 2500

    instrument = %{"id" => "card_1", "handler_id" => "pay", "type" => "card"}
    complete_body = %{"payment" => %{"instruments" => [instrument]}}

    {:ok, completed} =
      handler.complete_checkout(checkout["id"], %{conn | body_params: complete_body})

    assert completed["status"] == "completed"
    {:ok, order} = handler.get_order(completed["order"]["id"], conn)
    assert {:ok, _} = Validator.validate(order, :order)

    # Cart, catalog and conversion.
    {:ok, cart} =
      handler.create_cart(%{"line_items" => [%{"item" => %{"id" => "sample"}}]}, conn)

    assert {:ok, _} = Validator.validate(cart, :cart)

    {:ok, converted} = handler.create_checkout(%{"cart_id" => cart["id"]}, conn)
    assert [%{"item" => %{"id" => "sample"}}] = converted["line_items"]

    {:ok, search} = handler.search_products(%{"query" => "sample"}, conn)

    assert {:ok, _} =
             Validator.validate(
               Bazaar.Catalog.envelope(search, :search),
               :catalog_search_response
             )

    {:ok, product} = handler.get_product(%{"id" => "sample"}, conn)

    assert {:ok, _} =
             Validator.validate(
               Bazaar.Catalog.envelope(product, :lookup),
               :catalog_product_response
             )
  end

  test "the generated source is formatted", %{source: source} do
    assert IO.iodata_to_binary(Code.format_string!(source)) <> "\n" == source
  end

  test "the default capabilities leave carts and the catalog out, and unknown ones are rejected" do
    {_output, modules, source} = generate("ScaffoldDefault.Handler", [])

    default = default()
    assert default in modules

    assert default.capabilities() == [
             :checkout,
             :orders,
             :fulfillment,
             :buyer_consent
           ]

    refute function_exported?(default, :create_cart, 2)
    refute function_exported?(default, :search_products, 2)
    refute source =~ "Bazaar.Cart"

    assert_raise Mix.Error, ~r/Unknown capabilities \["loyalty"\]/, fn ->
      capture_io(fn ->
        Mix.Tasks.Bazaar.Gen.Handler.run([
          "Nope.Handler",
          "--capabilities",
          "loyalty",
          "--output-dir",
          @tmp
        ])
      end)
    end
  end
end
