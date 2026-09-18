defmodule Bazaar do
  @moduledoc """
  # Bazaar - The Unified Commerce Philosopher

  Elixir SDK for the Universal Commerce Protocol (UCP).

  Bazaar provides everything you need to build UCP-compliant merchant
  implementations in Elixir/Phoenix:

  - **Schemas**: Validated data structures using Ecto.Schema
  - **Phoenix Integration**: Router macros and plugs
  - **Shop, Store and Handler**: your facts, your persistence, every UCP callback by default
  - **Discovery**: Auto-generated `/.well-known/ucp` endpoints

  ## Quick Start

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        use Bazaar.Phoenix.Router

        bazaar_routes "/", MyApp.Commerce.Handler
      end

      defmodule MyApp.Commerce.Handler do
        use Bazaar.Handler, shop: MyApp.Shop, store: Bazaar.Store.ETS

        @impl true
        def capabilities, do: [:checkout, :orders, :fulfillment]
      end

      defmodule MyApp.Shop do
        use Bazaar.Shop

        @impl true
        def base_url, do: "https://shop.example"

        @impl true
        def item(id), do: MyApp.Products.item(id)
      end

  ## Links

  - [Universal Commerce Protocol](https://ucp.dev)
  - [UCP Specification](https://developers.google.com/merchant/ucp)
  """
end
