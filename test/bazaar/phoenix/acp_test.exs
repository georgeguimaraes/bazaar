defmodule Bazaar.Phoenix.AcpTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Bazaar.Phoenix.Controller
  alias Bazaar.Validator

  # A handler like the scaffold's, on Bazaar.Checkout with an in-test store.
  defmodule Handler do
    use Bazaar.Handler

    alias Bazaar.Checkout

    @impl true
    def capabilities, do: [:checkout, :orders, :fulfillment]

    def start, do: Agent.start_link(fn -> %{} end, name: __MODULE__)

    @impl true
    def create_checkout(params, _conn), do: {:ok, params |> Checkout.new() |> store() |> build()}

    @impl true
    def get_checkout(id, _conn) do
      case Agent.get(__MODULE__, &Map.get(&1, id)) do
        nil -> {:error, :not_found}
        state -> {:ok, build(state)}
      end
    end

    @impl true
    def update_checkout(id, params, _conn) do
      {:ok, id |> fetch() |> Checkout.apply_update(params) |> store() |> build()}
    end

    @impl true
    def complete_checkout(id, conn) do
      state = id |> fetch() |> Checkout.apply_update(conn.body_params)

      if Checkout.fulfillment_ready?(build(state)) and state.instruments != [] do
        {:ok, %{state | status: :completed, order_id: "order_1"} |> store() |> build()}
      else
        {:ok,
         build(state, [
           Checkout.error("missing", "Select a fulfillment option and pay", "$.fulfillment")
         ])}
      end
    end

    defp fetch(id), do: Agent.get(__MODULE__, &Map.fetch!(&1, id))

    defp store(state),
      do: tap(state, &Agent.update(__MODULE__, fn s -> Map.put(s, state.id, &1) end))

    defp build(state, messages \\ []) do
      Checkout.build(state,
        item: fn "roses" -> %{item: %{"title" => "Roses", "price" => 3500}, stock: nil} end,
        fulfillment_options: fn _destination, _context ->
          [
            %{
              "id" => "std",
              "title" => "Standard",
              "totals" => [%{"type" => "total", "amount" => 500}]
            }
          ]
        end,
        links: [%{"type" => "privacy_policy", "url" => "https://shop.test/privacy"}],
        order_url: &("https://shop.test/orders/" <> &1),
        messages: messages
      )
    end
  end

  defmodule Router do
    use Phoenix.Router
    use Bazaar.Phoenix.Router

    bazaar_routes("/acp", Handler, protocol: :acp)
  end

  setup do
    start_supervised!(%{id: Handler, start: {Handler, :start, []}})
    :ok
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
