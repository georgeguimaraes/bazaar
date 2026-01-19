defmodule Bazaar.Phoenix.Router do
  @moduledoc """
  Phoenix router macros for mounting UCP routes.

  ## Usage

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        use Bazaar.Phoenix.Router

        scope "/" do
          pipe_through :api
          bazaar_routes "/", MyApp.Commerce.Handler
        end
      end

  ## Generated Routes

  The `bazaar_routes/2` macro generates the following routes:

  | Method | Path | Description |
  |--------|------|-------------|
  | GET | `/.well-known/ucp` | Discovery endpoint |
  | POST | `/checkout-sessions` | Create checkout |
  | GET | `/checkout-sessions/:id` | Get checkout |
  | PATCH | `/checkout-sessions/:id` | Update checkout |
  | DELETE | `/checkout-sessions/:id` | Cancel checkout |
  | GET | `/orders/:id` | Get order |
  | POST | `/orders/:id/actions/cancel` | Cancel order |
  | POST | `/webhooks/ucp` | Webhook endpoint |

  ## Options

      bazaar_routes "/api/v1", MyApp.Handler,
        only: [:checkout, :orders],  # Limit capabilities
        discovery: true,              # Include discovery endpoint
        webhooks: true                # Include webhook endpoint
  """

  defmacro __using__(_opts) do
    quote do
      import Bazaar.Phoenix.Router, only: [bazaar_routes: 2, bazaar_routes: 3]
    end
  end

  @doc """
  Mounts UCP routes at the given path using the specified handler.

  ## Examples

      bazaar_routes "/", MyApp.Handler
      bazaar_routes "/api", MyApp.Handler, only: [:checkout]
  """
  defmacro bazaar_routes(path, handler, opts \\ []) do
    quote bind_quoted: [path: path, handler: handler, opts: opts] do
      scope path do
        # Discovery endpoint
        if Keyword.get(opts, :discovery, true) do
          get(
            "/.well-known/ucp",
            Bazaar.Phoenix.Controller,
            :discovery,
            assigns: %{bazaar_handler: handler}
          )
        end

        capabilities = Keyword.get(opts, :only, handler.capabilities())

        # Checkout capability routes
        if :checkout in capabilities do
          post(
            "/checkout-sessions",
            Bazaar.Phoenix.Controller,
            :create_checkout,
            assigns: %{bazaar_handler: handler}
          )

          get(
            "/checkout-sessions/:id",
            Bazaar.Phoenix.Controller,
            :get_checkout,
            assigns: %{bazaar_handler: handler}
          )

          patch(
            "/checkout-sessions/:id",
            Bazaar.Phoenix.Controller,
            :update_checkout,
            assigns: %{bazaar_handler: handler}
          )

          delete(
            "/checkout-sessions/:id",
            Bazaar.Phoenix.Controller,
            :cancel_checkout,
            assigns: %{bazaar_handler: handler}
          )
        end

        # Orders capability routes
        if :orders in capabilities do
          get(
            "/orders/:id",
            Bazaar.Phoenix.Controller,
            :get_order,
            assigns: %{bazaar_handler: handler}
          )

          post(
            "/orders/:id/actions/cancel",
            Bazaar.Phoenix.Controller,
            :cancel_order,
            assigns: %{bazaar_handler: handler}
          )
        end

        # Identity capability routes
        if :identity in capabilities do
          post(
            "/identity/link",
            Bazaar.Phoenix.Controller,
            :link_identity,
            assigns: %{bazaar_handler: handler}
          )
        end

        # Webhook endpoint
        if Keyword.get(opts, :webhooks, true) do
          post(
            "/webhooks/ucp",
            Bazaar.Phoenix.Controller,
            :webhook,
            assigns: %{bazaar_handler: handler}
          )
        end
      end
    end
  end
end
