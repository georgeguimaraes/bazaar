defmodule Bazaar.LocationTest do
  use ExUnit.Case, async: true

  alias Bazaar.Location

  @paris %{"latitude" => 48.8566, "longitude" => 2.3522}
  @london %{"latitude" => 51.5074, "longitude" => -0.1278}

  defp store(id, extra \\ %{}) do
    Map.merge(
      %{
        "id" => id,
        "name" => id,
        "timezone" => "Etc/UTC",
        "hours" => [
          %{"day" => "monday", "opens" => "09:00", "closes" => "17:00"},
          %{"day" => "friday", "opens" => "22:00", "closes" => "02:00"}
        ],
        "exception_hours" => [
          %{"title" => "Holiday", "valid_from" => "2026-05-25", "valid_through" => "2026-05-25"}
        ]
      },
      extra
    )
  end

  test "distance is the WGS 84 geodesic in meters" do
    equator_degree =
      Location.distance(%{"latitude" => 0, "longitude" => 0}, %{"latitude" => 0, "longitude" => 1})

    assert_in_delta equator_degree, 111_319.49, 0.01

    assert_in_delta Location.distance(@paris, @london), 343_556, 500
    assert Location.distance(@paris, @paris) == 0.0
  end

  describe "filter/3" do
    test "distance and amenities narrow, a location without coordinates never matches by distance" do
      paris =
        store("paris", %{
          "geo" => @paris,
          "amenities" => %{"dev.ucp.amenity.parking" => %{"description" => "Parking"}}
        })

      london = store("london", %{"geo" => @london})
      nowhere = store("nowhere")

      near_paris = %{"distance" => %{"center" => @paris, "max" => 1000}}
      assert {:ok, [^paris]} = Location.filter([paris, london, nowhere], near_paris)

      assert {:ok, [^paris]} =
               Location.filter([paris, london], %{
                 "filters" => %{"amenities" => ["dev.ucp.amenity.parking"]}
               })

      assert {:ok, []} =
               Location.filter([paris], %{
                 "filters" => %{
                   "amenities" => ["dev.ucp.amenity.parking", "dev.ucp.amenity.wi_fi"]
                 }
               })
    end

    test "serves and items go through the business, and are rejected without it" do
      shop = store("shop")
      request = %{"serves" => %{"point" => @paris}, "filters" => %{"items" => ["roses"]}}

      assert Location.filter([shop], request) == {:error, :unsupported_filter}

      assert Location.filter([shop], %{"distance" => %{"center" => %{"latitude" => 1}}}) ==
               {:error, :invalid_distance}

      assert {:ok, [^shop]} =
               Location.filter([shop], request,
                 serves: fn _location, %{"point" => _} -> true end,
                 items: fn _location, ["roses"] -> true end
               )

      assert {:ok, []} =
               Location.filter([shop], request,
                 serves: fn _, _ -> false end,
                 items: fn _, _ -> true end
               )
    end

    test "open_at follows the weekday hours, overnight intervals and exception closures" do
      shop = store("shop")

      assert Location.open?(shop, ~U[2026-05-18 12:00:00Z]), "a Monday at noon"
      refute Location.open?(shop, ~U[2026-05-18 17:00:00Z]), "closing time is exclusive"
      refute Location.open?(shop, ~U[2026-05-19 12:00:00Z]), "no Tuesday hours"

      assert Location.open?(shop, ~U[2026-05-22 23:30:00Z]),
             "Friday night, still the Friday interval"

      refute Location.open?(shop, ~U[2026-05-25 12:00:00Z]), "closed on the holiday exception"
      refute Location.open?(store("no-tz", %{"timezone" => nil}), ~U[2026-05-18 12:00:00Z])

      assert {:ok, [^shop]} =
               Location.filter([shop], %{
                 "filters" => %{"hours" => %{"open_at" => "2026-05-18T12:00:00Z"}}
               })

      assert {:ok, []} =
               Location.filter([shop], %{
                 "filters" => %{"hours" => %{"open_at" => "2026-05-25T12:00:00Z"}}
               })
    end

    test "evaluating another zone without a time zone database says what to add" do
      assert_raise ArgumentError, ~r/tz or tzdata/, fn ->
        Location.open?(store("ny", %{"timezone" => "America/New_York"}), ~U[2026-05-18 12:00:00Z])
      end
    end
  end

  test "lookup dedupes, correlates inputs, reports unknown ids and the batch limit" do
    stores = [store("a"), store("b"), store("c")]

    assert {[%{"id" => "a", "inputs" => [%{"id" => "a"}]}], []} =
             Location.lookup(stores, ["a", "a"])

    {found, messages} = Location.lookup(stores, ["c", "nope", "a"], max: 2)
    assert Enum.map(found, & &1["id"]) == ["c"]

    assert [
             %{
               "type" => "info",
               "code" => "not_found",
               "content" => "Unable to find the location nope."
             },
             %{
               "type" => "info",
               "code" => "batch_limit_applied",
               "content" => "Only the first 2 identifiers were processed; 1 were not."
             }
           ] = messages
  end

  test "envelope names the capability that answered" do
    assert %{"ucp" => %{"capabilities" => %{"dev.ucp.common.location.lookup" => _}}} =
             Location.envelope(%{"locations" => []}, :lookup)
  end
end
