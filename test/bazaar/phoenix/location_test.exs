defmodule Bazaar.Phoenix.LocationTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Bazaar.Phoenix.Controller

  defmodule Handler do
    use Bazaar.Handler

    @impl true
    def capabilities, do: [:checkout, :location]

    @stores [
      %{
        "id" => "loc_1",
        "name" => "Downtown",
        "address" => %{"address_locality" => "Springfield", "address_country" => "US"},
        "geo" => %{"latitude" => 39.7817, "longitude" => -89.6501},
        "amenities" => %{
          "dev.ucp.amenity.shopping.in_store_pickup" => %{"description" => "In-store pickup"}
        },
        "timezone" => "Etc/UTC",
        "hours" => [%{"day" => "monday", "opens" => "09:00", "closes" => "17:00"}]
      }
    ]

    @impl true
    def search_locations(params, _conn) do
      with {:ok, locations} <- Bazaar.Location.filter(@stores, params) do
        {page, pagination} = Bazaar.Location.paginate(locations, params["pagination"])
        {:ok, %{"locations" => page, "pagination" => pagination}}
      end
    end

    @impl true
    def lookup_locations(%{"ids" => ids}, _conn) do
      {locations, messages} = Bazaar.Location.lookup(@stores, ids)
      {:ok, %{"locations" => locations, "messages" => messages}}
    end
  end

  defmodule Router do
    use Phoenix.Router
    use Bazaar.Phoenix.Router

    bazaar_routes("/", Handler)
  end

  test "mounts the two location POSTs" do
    routes =
      for route <- Router.__routes__(), route.path =~ "locations", do: {route.verb, route.path}

    assert routes == [{:post, "/locations/search"}, {:post, "/locations/lookup"}]
  end

  defp call(action, params) do
    :post
    |> conn("/locations", params)
    |> assign(:bazaar_handler, Handler)
    |> then(&apply(Controller, action, [&1, params]))
    |> then(&{&1.status, JSON.decode!(&1.resp_body)})
  end

  test "answers spec-valid search and lookup documents, 422 for what the business can't filter" do
    assert {200, search} =
             call(:search_locations, %{
               "filters" => %{"amenities" => ["dev.ucp.amenity.shopping.in_store_pickup"]}
             })

    assert {:ok, _} = Bazaar.Validator.validate(search, :location_search_response)
    assert [%{"id" => "loc_1"}] = search["locations"]
    assert %{"dev.ucp.common.location.search" => _} = search["ucp"]["capabilities"]

    assert {200, lookup} = call(:lookup_locations, %{"ids" => ["loc_1", "nope"]})
    assert {:ok, _} = Bazaar.Validator.validate(lookup, :location_lookup_response)
    assert [%{"id" => "loc_1", "inputs" => [%{"id" => "loc_1"}]}] = lookup["locations"]
    assert [%{"code" => "not_found"}] = lookup["messages"]

    assert {422, %{"messages" => [%{"code" => "unsupported_filter"}]}} =
             call(:search_locations, %{
               "serves" => %{"point" => %{"latitude" => 0, "longitude" => 0}}
             })

    assert {422, %{"messages" => [%{"code" => "missing_ids"}]}} = call(:lookup_locations, %{})
  end
end
