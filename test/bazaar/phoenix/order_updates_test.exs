defmodule Bazaar.Phoenix.OrderUpdatesTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  defmodule Handler do
    use Bazaar.Handler

    @impl true
    def capabilities, do: [:checkout, :orders]

    @impl true
    def get_order(id, _conn), do: {:ok, %{"id" => id}}

    @impl true
    def update_order("missing", _params, _conn), do: {:error, :not_found}

    def update_order(_id, %{"adjustments" => bad}, _conn) when not is_list(bad),
      do: {:error, :invalid_adjustments}

    def update_order(id, params, _conn),
      do: {:ok, %{"id" => id, "adjustments" => params["adjustments"] || []}}
  end

  defmodule WithUpdates do
    use Phoenix.Router
    use Bazaar.Phoenix.Router

    bazaar_routes("/", Handler, order_updates: true)
  end

  defmodule WithoutUpdates do
    use Phoenix.Router
    use Bazaar.Phoenix.Router

    bazaar_routes("/", Handler)
  end

  defp put_route(router),
    do: Enum.find(router.__routes__(), &(&1.path == "/orders/:id" and &1.verb == :put))

  test "PUT /orders/:id is mounted only with order_updates: true" do
    assert put_route(WithUpdates).plug_opts == :update_order
    assert put_route(WithoutUpdates) == nil
  end

  defp update(id, params) do
    :put
    |> conn("/orders/#{id}", params)
    |> assign(:bazaar_handler, Handler)
    |> Bazaar.Phoenix.Controller.update_order(Map.put(params, "id", id))
  end

  test "update_order renders the updated order, 404 for unknown ids and 422 for rejected updates" do
    ok = update("order_1", %{"adjustments" => [%{"id" => "adj_1", "status" => "pending"}]})
    assert ok.status == 200

    assert JSON.decode!(ok.resp_body)["adjustments"] == [
             %{"id" => "adj_1", "status" => "pending"}
           ]

    assert update("missing", %{}).status == 404

    rejected = update("order_1", %{"adjustments" => %{"id" => "adj_1"}})
    assert rejected.status == 422
    assert [%{"code" => "invalid_adjustments"}] = JSON.decode!(rejected.resp_body)["messages"]
  end
end
