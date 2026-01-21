defmodule Bazaar do
  @moduledoc """
  # Bazaar - The Unified Commerce Philosopher

  Elixir SDK for the Universal Commerce Protocol (UCP).

  Bazaar provides everything you need to build UCP-compliant merchant
  implementations in Elixir/Phoenix:

  - **Schemas**: Validated data structures using Ecto.Schema
  - **Phoenix Integration**: Router macros and plugs
  - **Handler Behaviour**: Define your commerce logic
  - **Discovery**: Auto-generated `/.well-known/ucp` endpoints

  ## Quick Start

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        use Bazaar.Phoenix.Router

        bazaar_routes "/", MyApp.Commerce.Handler
      end

      defmodule MyApp.Commerce.Handler do
        use Bazaar.Handler

        @impl true
        def create_checkout(params, conn) do
          # Your business logic
          {:ok, checkout}
        end
      end

  ## Links

  - [Universal Commerce Protocol](https://ucp.dev)
  - [UCP Specification](https://developers.google.com/merchant/ucp)
  """
end
