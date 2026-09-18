defmodule FlowerShop.LocationTest do
  use ExUnit.Case, async: true

  alias Bazaar.Validator
  alias FlowerShop.Handler

  defp search(params) do
    {:ok, doc} = Handler.search_locations(params, nil)

    assert {:ok, _} =
             Validator.validate(Bazaar.Location.envelope(doc, :search), :location_search_response)

    Enum.map(doc["locations"], & &1["id"])
  end

  # Downtown Springfield, and a point in Manhattan.
  @springfield %{"latitude" => 39.8, "longitude" => -89.65}
  @manhattan %{"latitude" => 40.75, "longitude" => -73.99}

  test "finds stores by distance, service area, amenities and stock" do
    assert search(%{"distance" => %{"center" => @springfield, "max" => 5_000}}) == [
             "loc_springfield"
           ]

    assert search(%{"serves" => %{"point" => @manhattan}}) == ["loc_metropolis"]

    assert search(%{
             "serves" => %{"address" => %{"address_region" => "IL", "address_country" => "US"}}
           }) == ["loc_springfield"]

    assert search(%{"filters" => %{"amenities" => ["dev.ucp.amenity.shopping.curbside_pickup"]}}) ==
             ["loc_springfield"]

    assert search(%{"filters" => %{"items" => ["bouquet_roses"]}}) == [
             "loc_springfield",
             "loc_metropolis"
           ]

    assert search(%{"filters" => %{"items" => ["gardenias"]}}) == []
    assert search(%{"query" => "metro"}) == ["loc_metropolis"]
  end

  test "evaluates opening hours in each store's own time zone" do
    # 20:30 UTC on a Wednesday is 15:30 in Springfield (open) and 16:30 in Metropolis (open).
    assert search(%{"filters" => %{"hours" => %{"open_at" => "2026-06-10T20:30:00Z"}}}) == [
             "loc_springfield",
             "loc_metropolis"
           ]

    # 23:30 UTC is 18:30 in Springfield (closed at 18:00) and 19:30 in Metropolis (closed).
    assert search(%{"filters" => %{"hours" => %{"open_at" => "2026-06-10T23:30:00Z"}}}) == []
    # Saturday noon: Springfield opens, Metropolis has no Saturday hours.
    assert search(%{"filters" => %{"hours" => %{"open_at" => "2026-06-13T17:00:00Z"}}}) == [
             "loc_springfield"
           ]

    # Independence Day closes Springfield.
    assert search(%{"filters" => %{"hours" => %{"open_at" => "2026-07-04T17:00:00Z"}}}) == []
  end

  test "looks stores up with correlation and reports what it can't find" do
    {:ok, doc} =
      Handler.lookup_locations(
        %{"ids" => ["loc_metropolis", "loc_nowhere", "loc_metropolis"]},
        nil
      )

    assert {:ok, _} =
             Validator.validate(Bazaar.Location.envelope(doc, :lookup), :location_lookup_response)

    assert [%{"id" => "loc_metropolis", "inputs" => [%{"id" => "loc_metropolis"}]}] =
             doc["locations"]

    assert [%{"code" => "not_found"}] = doc["messages"]
  end
end
