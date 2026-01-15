defmodule Ucphi.Phoenix.Router do
  @moduledoc """
  Phoenix router macros for mounting UCP routes.

  ## Usage

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        use Ucphi.Phoenix.Router

        scope "/" do
          pipe_through :api
          ucphi_routes "/", MyApp.Commerce.Handler
        end
      end

  ## Generated Routes

  The `ucphi_routes/2` macro generates the following routes:

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

      ucphi_routes "/api/v1", MyApp.Handler,
        only: [:checkout, :orders],  # Limit capabilities
        discovery: true,              # Include discovery endpoint
        webhooks: true                # Include webhook endpoint
  """

  defmacro __using__(_opts) do
    quote do
      import Ucphi.Phoenix.Router, only: [ucphi_routes: 2, ucphi_routes: 3]
    end
  end

  @doc """
  Mounts UCP routes at the given path using the specified handler.

  ## Examples

      ucphi_routes "/", MyApp.Handler
      ucphi_routes "/api", MyApp.Handler, only: [:checkout]
  """
  defmacro ucphi_routes(path, handler, opts \\ []) do
    quote bind_quoted: [path: path, handler: handler, opts: opts] do
      scope path do
        # Discovery endpoint
        if Keyword.get(opts, :discovery, true) do
          get(
            "/.well-known/ucp",
            Ucphi.Phoenix.Controller,
            :discovery,
            assigns: %{ucphi_handler: handler}
          )
        end

        capabilities = Keyword.get(opts, :only, handler.capabilities())

        # Checkout capability routes
        if :checkout in capabilities do
          post(
            "/checkout-sessions",
            Ucphi.Phoenix.Controller,
            :create_checkout,
            assigns: %{ucphi_handler: handler}
          )

          get(
            "/checkout-sessions/:id",
            Ucphi.Phoenix.Controller,
            :get_checkout,
            assigns: %{ucphi_handler: handler}
          )

          patch(
            "/checkout-sessions/:id",
            Ucphi.Phoenix.Controller,
            :update_checkout,
            assigns: %{ucphi_handler: handler}
          )

          delete(
            "/checkout-sessions/:id",
            Ucphi.Phoenix.Controller,
            :cancel_checkout,
            assigns: %{ucphi_handler: handler}
          )
        end

        # Orders capability routes
        if :orders in capabilities do
          get(
            "/orders/:id",
            Ucphi.Phoenix.Controller,
            :get_order,
            assigns: %{ucphi_handler: handler}
          )

          post(
            "/orders/:id/actions/cancel",
            Ucphi.Phoenix.Controller,
            :cancel_order,
            assigns: %{ucphi_handler: handler}
          )
        end

        # Identity capability routes
        if :identity in capabilities do
          post(
            "/identity/link",
            Ucphi.Phoenix.Controller,
            :link_identity,
            assigns: %{ucphi_handler: handler}
          )
        end

        # Webhook endpoint
        if Keyword.get(opts, :webhooks, true) do
          post(
            "/webhooks/ucp",
            Ucphi.Phoenix.Controller,
            :webhook,
            assigns: %{ucphi_handler: handler}
          )
        end
      end
    end
  end
end
