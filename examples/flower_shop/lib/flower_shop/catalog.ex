defmodule FlowerShop.Catalog do
  @moduledoc """
  The flower shop's data, mirroring `test_data/flower_shop/*.csv` in the UCP
  conformance suite so the suite's fixtures line up with what this server sells.

  Prices are integer minor units (cents).
  """

  @products %{
    "bouquet_roses" => %{
      title: "Bouquet of Red Roses",
      description: "A dozen long-stemmed red roses, hand-tied",
      category: "bouquets",
      price: 3500,
      stock: 1000,
      image_url: "https://example.com/roses.jpg"
    },
    "pot_ceramic" => %{
      title: "Ceramic Pot",
      description: "Glazed ceramic pot with a drainage hole, 15cm",
      category: "pots",
      price: 1500,
      stock: 2000,
      image_url: "https://example.com/pot.jpg"
    },
    "bouquet_sunflowers" => %{
      title: "Sunflower Bundle",
      description: "Five bright sunflowers wrapped in kraft paper",
      category: "bouquets",
      price: 2500,
      stock: 500,
      image_url: "https://example.com/sunflowers.jpg"
    },
    "bouquet_tulips" => %{
      title: "Spring Tulips",
      description: "Twenty mixed tulips, fresh from the field",
      category: "bouquets",
      price: 3000,
      stock: 1500,
      image_url: "https://example.com/tulips.jpg"
    },
    "orchid_white" => %{
      title: "White Orchid",
      description: "Potted white phalaenopsis orchid with two stems",
      category: "plants",
      price: 4500,
      stock: 800,
      image_url: "https://example.com/orchid.jpg"
    },
    "gardenias" => %{
      title: "Gardenias",
      description: "Fragrant gardenia blooms, seasonal",
      category: "bouquets",
      price: 2000,
      stock: 0,
      image_url: "https://example.com/gardenias.jpg"
    }
  }

  @currency "USD"

  @discounts %{
    "10OFF" => %{type: :percentage, value: 10, title: "10% Off"},
    "WELCOME20" => %{type: :percentage, value: 20, title: "20% Off"},
    "FIXED500" => %{type: :fixed_amount, value: 500, title: "$5.00 Off"}
  }

  # Free standard shipping on orders of $100 or more, or on any order with roses.
  @free_shipping_min_subtotal 10_000
  @free_shipping_items ["bouquet_roses"]

  # `country_code: :default` applies to every country that has no exact match
  # for the same service level.
  @shipping_rates [
    %{
      id: "std-ship",
      country_code: :default,
      service_level: :standard,
      price: 500,
      title: "Standard Shipping"
    },
    %{
      id: "exp-ship-us",
      country_code: "US",
      service_level: :express,
      price: 1500,
      title: "Express Shipping (US)"
    },
    %{
      id: "exp-ship-intl",
      country_code: :default,
      service_level: :express,
      price: 2500,
      title: "International Express"
    }
  ]

  @customers %{
    "john.doe@example.com" => %{
      name: "John Doe",
      addresses: [
        %{
          "id" => "addr_1",
          "street_address" => "123 Main St",
          "address_locality" => "Springfield",
          "address_region" => "IL",
          "postal_code" => "62704",
          "address_country" => "US"
        },
        %{
          "id" => "addr_2",
          "street_address" => "456 Oak Ave",
          "address_locality" => "Metropolis",
          "address_region" => "NY",
          "postal_code" => "10012",
          "address_country" => "US"
        }
      ]
    },
    "jane.smith@example.com" => %{
      name: "Jane Smith",
      addresses: [
        %{
          "id" => "addr_3",
          "street_address" => "789 Pine Ln",
          "address_locality" => "Springfield",
          "address_region" => "KS",
          "postal_code" => "66002",
          "address_country" => "US"
        }
      ]
    },
    "jane.doe@example.com" => %{name: "Jane Doe", addresses: []}
  }

  @payment_handler %{namespace: "dev.flowershop.mock", id: "mock_payment_handler"}

  def product(id), do: Map.get(@products, id)

  @doc """
  Every product as the UCP catalog document. Each product has one variant
  whose id is the product's, so a catalog id is what checkout expects as
  `item.id`.
  """
  def products, do: Enum.map(@products, fn {id, product} -> product_document(id, product) end)

  defp product_document(id, product) do
    price = %{"amount" => product.price, "currency" => @currency}

    variant = %{
      "id" => id,
      "title" => product.title,
      "description" => %{"plain" => product.description},
      "price" => price,
      "availability" => %{
        "available" => product.stock > 0,
        "status" => if(product.stock > 0, do: "in_stock", else: "out_of_stock")
      }
    }

    %{
      "id" => id,
      "title" => product.title,
      "description" => %{"plain" => product.description},
      "categories" => [%{"value" => product.category}],
      "price_range" => %{"min" => price, "max" => price},
      "media" => [%{"type" => "image", "url" => product.image_url, "alt_text" => product.title}],
      "variants" => [variant]
    }
  end

  def discount(code) when is_binary(code), do: Map.get(@discounts, String.upcase(code))
  def discount(_), do: nil

  def canonical_discount_code(code), do: String.upcase(code)

  @doc "Stored addresses for a known customer email, `nil` for an unknown one."
  def customer_addresses(email) when is_binary(email) do
    case Map.get(@customers, String.downcase(email)) do
      nil -> nil
      customer -> customer.addresses
    end
  end

  def customer_addresses(_), do: nil

  @doc """
  Shipping options for a destination country: one per service level, the
  exact country match winning over the default rate. Standard shipping is free
  when a free-shipping promotion applies to the checkout.
  """
  def shipping_options(country, opts \\ []) do
    free? = Keyword.get(opts, :free_shipping, false)

    @shipping_rates
    |> Enum.group_by(& &1.service_level)
    |> Enum.map(fn {_level, rates} ->
      Enum.find(rates, &(&1.country_code == country)) ||
        Enum.find(rates, &(&1.country_code == :default))
    end)
    |> Enum.sort_by(& &1.price)
    |> Enum.map(fn
      %{service_level: :standard} = rate when free? ->
        %{rate | price: 0, title: rate.title <> " (Free)"}

      rate ->
        rate
    end)
  end

  def free_shipping?(subtotal, product_ids) do
    subtotal >= @free_shipping_min_subtotal or
      Enum.any?(product_ids, &(&1 in @free_shipping_items))
  end

  def payment_handler, do: @payment_handler
end
