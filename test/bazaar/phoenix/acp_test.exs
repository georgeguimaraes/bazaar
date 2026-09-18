defmodule Bazaar.Phoenix.AcpTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Bazaar.Phoenix.Controller
  alias Bazaar.Validator

  defmodule Handler do
    use Bazaar.Handler, shop: Bazaar.TestShop, store: Bazaar.Store.ETS

    @impl true
    def capabilities, do: [:checkout, :orders, :fulfillment]
  end

  defmodule Router do
    use Phoenix.Router
    use Bazaar.Phoenix.Router

    bazaar_routes("/acp", Handler, protocol: :acp)
  end

  @create %{
    "currency" => "USD",
    "line_items" => [%{"id" => "roses", "quantity" => 1}],
    "buyer" => %{"email" => "john@example.com"},
    "fulfillment_details" => %{
      "name" => "John Smith",
      "address" => %{
        "name" => "John Smith",
        "line_one" => "1 Main",
        "city" => "SF",
        "state" => "CA",
        "country" => "US",
        "postal_code" => "94102"
      }
    },
    "capabilities" => %{}
  }

  # The bundled create schema's Item has no quantity; the RFC's example does.
  defp without_quantity(body),
    do: update_in(body["line_items"], &Enum.map(&1, fn item -> Map.delete(item, "quantity") end))

  defp call(action, method, path, params) do
    method
    |> conn(path, params)
    |> assign(:bazaar_handler, Handler)
    |> assign(:bazaar_protocol, :acp)
    |> then(&apply(Controller, action, [&1, params]))
    |> then(&{&1.status, JSON.decode!(&1.resp_body)})
  end

  test "mounts ACP's checkout session routes" do
    paths = for route <- Router.__routes__(), do: {route.verb, route.path}

    assert {:post, "/acp/checkout_sessions"} in paths
    assert {:post, "/acp/checkout_sessions/:id/complete"} in paths
    refute Enum.any?(paths, fn {_verb, path} -> path =~ "well-known" or path =~ "orders" end)
  end

  test "creates, selects an option, and completes through the ACP shapes" do
    assert {:ok, _} = Validator.validate(without_quantity(@create), :checkout_create_req)

    assert {201, session} = call(:create_checkout, :post, "/acp/checkout_sessions", @create)
    assert {:ok, _} = Validator.validate(session, :checkout_session)
    assert session["status"] == "not_ready_for_payment"
    assert [%{"id" => "std", "title" => "Standard"}] = session["fulfillment_options"]
    assert session["fulfillment_details"]["address"]["line_one"] == "1 Main"

    id = session["id"]

    update = %{
      "id" => id,
      "selected_fulfillment_options" => [
        %{"type" => "shipping", "option_id" => "std", "item_ids" => ["roses"]}
      ]
    }

    assert {200, updated} = call(:update_checkout, :post, "/acp/checkout_sessions/#{id}", update)
    assert {:ok, _} = Validator.validate(updated, :checkout_session)
    assert updated["status"] == "ready_for_payment"
    assert Enum.find(updated["totals"], &(&1["type"] == "total"))["amount"] == 4000

    complete = %{
      "id" => id,
      "payment_data" => %{"handler_id" => "card", "instrument" => %{"type" => "card"}}
    }

    assert {200, completed} =
             call(:complete_checkout, :post, "/acp/checkout_sessions/#{id}/complete", complete)

    assert {:ok, _} = Validator.validate(Map.delete(completed, "order"), :checkout_session)
    assert completed["status"] == "completed"
    assert completed["order"]["checkout_session_id"] == id

    assert {404, %{"type" => "invalid_request", "code" => "not_found"}} =
             call(:get_checkout, :get, "/acp/checkout_sessions/nope", %{"id" => "nope"})
  end
end
