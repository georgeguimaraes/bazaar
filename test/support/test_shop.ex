defmodule Bazaar.TestShop do
  @moduledoc false
  # A two-product shop with one flat rate, enough for handlers under test.
  use Bazaar.Shop

  @impl true
  def base_url, do: "https://shop.test"

  @impl true
  def item("roses"), do: %{item: %{"title" => "Roses", "price" => 3500}, stock: nil}
  def item("pot"), do: %{item: %{"title" => "Pot", "price" => 1500}, stock: 0}
  def item(_id), do: nil

  @impl true
  def fulfillment_options(_destination, _context) do
    [%{"id" => "std", "title" => "Standard", "totals" => [%{"type" => "total", "amount" => 500}]}]
  end

  @impl true
  def products do
    [
      %{
        "id" => "roses",
        "title" => "Roses",
        "description" => %{"plain" => "A dozen"},
        "price_range" => %{
          "min" => %{"amount" => 3500, "currency" => "USD"},
          "max" => %{"amount" => 3500, "currency" => "USD"}
        },
        "variants" => [
          %{
            "id" => "roses",
            "title" => "Roses",
            "description" => %{"plain" => "A dozen"},
            "price" => %{"amount" => 3500, "currency" => "USD"}
          }
        ]
      }
    ]
  end

  @impl true
  def locations do
    [
      %{
        "id" => "loc_1",
        "name" => "Downtown",
        "geo" => %{"latitude" => 39.7817, "longitude" => -89.6501},
        "amenities" => %{"dev.ucp.amenity.parking" => %{"description" => "Parking"}},
        "timezone" => "Etc/UTC",
        "hours" => [%{"day" => "monday", "opens" => "09:00", "closes" => "17:00"}]
      }
    ]
  end
end
