defmodule Ucphi do
  @moduledoc """
  # Ucphi - The Unified Commerce Philosopher

  Elixir SDK for the Universal Commerce Protocol (UCP).

  Ucphi provides everything you need to build UCP-compliant merchant
  implementations in Elixir/Phoenix:

  - **Schemas**: Validated data structures using Schemecto
  - **Phoenix Integration**: Router macros and plugs
  - **Handler Behaviour**: Define your commerce logic
  - **Discovery**: Auto-generated `/.well-known/ucp` endpoints

  ## Quick Start

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        use Ucphi.Phoenix.Router

        ucphi_routes "/", MyApp.Commerce.Handler
      end

      defmodule MyApp.Commerce.Handler do
        use Ucphi.Handler

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

  @doc """
  Returns the current Ucphi version.
  """
  def version, do: "0.1.0"
end
