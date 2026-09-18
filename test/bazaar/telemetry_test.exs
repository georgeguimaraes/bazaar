defmodule Bazaar.TelemetryTest do
  use ExUnit.Case, async: true

  import Bazaar.Test

  defmodule Handler do
    use Bazaar.Handler, shop: Bazaar.TestShop, store: Bazaar.Store.ETS

    @impl true
    def capabilities, do: [:checkout, :orders, :cart, :catalog, :location]
  end

  @events [
    [:bazaar, :checkout, :create],
    [:bazaar, :checkout, :get],
    [:bazaar, :cart, :create],
    [:bazaar, :catalog, :search],
    [:bazaar, :location, :search],
    [:bazaar, :order, :get]
  ]

  test "every operation the controller serves is a telemetry span" do
    test = self()
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach_many(
      handler_id,
      Enum.map(@events, &(&1 ++ [:stop])),
      fn event, measurements, metadata, _ ->
        send(test, {:span, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    {201, checkout} =
      request(
        Handler,
        :create_checkout,
        checkout_request(%{"line_items" => [%{"item" => %{"id" => "roses"}}]})
      )

    {200, _} = request(Handler, :get_checkout, %{"id" => checkout["id"]})

    {201, _} =
      request(Handler, :create_cart, %{"line_items" => [%{"item" => %{"id" => "roses"}}]})

    {200, _} = request(Handler, :search_products, %{"query" => "rose"})
    {200, _} = request(Handler, :search_locations, %{})
    {404, _} = request(Handler, :get_order, %{"id" => "nope"})

    id = checkout["id"]

    assert_received {:span, [:bazaar, :checkout, :create, :stop], %{duration: _},
                     %{checkout_id: ^id, status: "incomplete"}}

    assert_received {:span, [:bazaar, :checkout, :get, :stop], _, %{checkout_id: ^id}}
    assert_received {:span, [:bazaar, :cart, :create, :stop], _, %{cart_id: _}}
    assert_received {:span, [:bazaar, :catalog, :search, :stop], _, %{count: 1}}
    assert_received {:span, [:bazaar, :location, :search, :stop], _, %{count: 1}}
    assert_received {:span, [:bazaar, :order, :get, :stop], _, %{order_id: "nope"}}
  end
end
