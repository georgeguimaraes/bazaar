defmodule Bazaar.Phoenix.Router do
  @moduledoc """
  Phoenix router macros for mounting UCP and ACP routes.

  ## Usage

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        use Bazaar.Phoenix.Router

        pipeline :api do
          plug :accepts, ["json"]
        end

        # Optional: Add schema validation
        pipeline :bazaar_validated do
          plug Bazaar.Plugs.ValidateRequest
          plug Bazaar.Plugs.ValidateResponse
        end

        scope "/" do
          pipe_through [:api, :bazaar_validated]

          # UCP protocol (default)
          bazaar_routes "/", MyApp.Commerce.Handler

          # ACP protocol
          bazaar_routes "/acp", MyApp.Commerce.Handler, protocol: :acp
        end
      end

  ## Schema Validation

  Bazaar includes plugs for validating requests and responses against
  Smelter-generated Ecto schemas:

  - `Bazaar.Plugs.ValidateRequest` - Validates incoming request bodies
  - `Bazaar.Plugs.ValidateResponse` - Validates outgoing response bodies

  Both plugs are optional but recommended for catching schema violations
  early in development.

  ## Generated Routes (UCP)

  | Method | Path | Description |
  |--------|------|-------------|
  | GET | `/.well-known/ucp` | Discovery endpoint |
  | POST | `/checkout-sessions` | Create checkout |
  | GET | `/checkout-sessions/:id` | Get checkout |
  | PATCH | `/checkout-sessions/:id` | Update checkout |
  | POST | `/checkout-sessions/:id/actions/complete` | Complete checkout |
  | DELETE | `/checkout-sessions/:id` | Cancel checkout |
  | GET | `/orders/:id` | Get order |
  | POST | `/orders/:id/actions/cancel` | Cancel order |
  | GET | `/products` | List products |
  | GET | `/products/search` | Search products |
  | GET | `/products/:id` | Get product |
  | POST | `/webhooks/ucp` | Webhook endpoint |

  ## Generated Routes (ACP)

  ACP uses slightly different URL patterns and HTTP methods:

  | Method | Path | Description |
  |--------|------|-------------|
  | POST | `/checkout_sessions` | Create checkout |
  | GET | `/checkout_sessions/:id` | Get checkout |
  | POST | `/checkout_sessions/:id` | Update checkout |
  | POST | `/checkout_sessions/:id/complete` | Complete checkout |
  | POST | `/checkout_sessions/:id/cancel` | Cancel checkout |

  Note: ACP does not have a discovery endpoint.

  ## Options

      bazaar_routes "/api/v1", MyApp.Handler,
        protocol: :ucp,               # Protocol: :ucp (default) or :acp
        only: [:checkout, :orders],   # Limit capabilities
        discovery: true,              # Include discovery endpoint (UCP only)
        webhooks: true,               # Include webhook endpoint
        validate_requests: true,      # Enable request validation (requires plug in pipeline)
        validate_responses: true      # Enable response validation (requires plug in pipeline)
  """

  defmacro __using__(_opts) do
    quote do
      import Bazaar.Phoenix.Router, only: [bazaar_routes: 2, bazaar_routes: 3]
    end
  end

  @doc """
  Mounts protocol routes at the given path using the specified handler.

  ## Examples

      # UCP protocol (default)
      bazaar_routes "/", MyApp.Handler

      # ACP protocol
      bazaar_routes "/acp", MyApp.Handler, protocol: :acp

      # Multiple protocols at different paths
      bazaar_routes "/ucp", MyApp.Handler, protocol: :ucp
      bazaar_routes "/acp", MyApp.Handler, protocol: :acp
  """
  defmacro bazaar_routes(path, handler, opts \\ []) do
    quote bind_quoted: [path: path, handler: handler, opts: opts] do
      protocol = Keyword.get(opts, :protocol, :ucp)
      assigns = %{bazaar_handler: handler, bazaar_protocol: protocol}

      scope path do
        # Discovery endpoint (UCP only)
        if protocol == :ucp and Keyword.get(opts, :discovery, true) do
          get(
            "/.well-known/ucp",
            Bazaar.Phoenix.Controller,
            :discovery,
            assigns: assigns
          )
        end

        capabilities = Keyword.get(opts, :only, handler.capabilities())

        # Checkout capability routes
        if :checkout in capabilities do
          case protocol do
            :ucp ->
              # UCP: hyphenated paths, PATCH for update, DELETE for cancel
              post(
                "/checkout-sessions",
                Bazaar.Phoenix.Controller,
                :create_checkout,
                assigns: assigns
              )

              get(
                "/checkout-sessions/:id",
                Bazaar.Phoenix.Controller,
                :get_checkout,
                assigns: assigns
              )

              patch(
                "/checkout-sessions/:id",
                Bazaar.Phoenix.Controller,
                :update_checkout,
                assigns: assigns
              )

              post(
                "/checkout-sessions/:id/actions/complete",
                Bazaar.Phoenix.Controller,
                :complete_checkout,
                assigns: assigns
              )

              delete(
                "/checkout-sessions/:id",
                Bazaar.Phoenix.Controller,
                :cancel_checkout,
                assigns: assigns
              )

            :acp ->
              # ACP: underscored paths, POST for update and cancel
              post(
                "/checkout_sessions",
                Bazaar.Phoenix.Controller,
                :create_checkout,
                assigns: assigns
              )

              get(
                "/checkout_sessions/:id",
                Bazaar.Phoenix.Controller,
                :get_checkout,
                assigns: assigns
              )

              post(
                "/checkout_sessions/:id",
                Bazaar.Phoenix.Controller,
                :update_checkout,
                assigns: assigns
              )

              post(
                "/checkout_sessions/:id/complete",
                Bazaar.Phoenix.Controller,
                :complete_checkout,
                assigns: assigns
              )

              post(
                "/checkout_sessions/:id/cancel",
                Bazaar.Phoenix.Controller,
                :cancel_checkout,
                assigns: assigns
              )
          end
        end

        # Orders capability routes (UCP only for now)
        if :orders in capabilities and protocol == :ucp do
          get(
            "/orders/:id",
            Bazaar.Phoenix.Controller,
            :get_order,
            assigns: assigns
          )

          post(
            "/orders/:id/actions/cancel",
            Bazaar.Phoenix.Controller,
            :cancel_order,
            assigns: assigns
          )
        end

        # Identity capability routes (UCP only for now)
        if :identity in capabilities and protocol == :ucp do
          post(
            "/identity/link",
            Bazaar.Phoenix.Controller,
            :link_identity,
            assigns: assigns
          )
        end

        # Catalog capability routes (UCP only for now)
        if :catalog in capabilities and protocol == :ucp do
          get(
            "/products",
            Bazaar.Phoenix.Controller,
            :list_products,
            assigns: assigns
          )

          get(
            "/products/search",
            Bazaar.Phoenix.Controller,
            :search_products,
            assigns: assigns
          )

          get(
            "/products/:id",
            Bazaar.Phoenix.Controller,
            :get_product,
            assigns: assigns
          )
        end

        # Webhook endpoint (UCP only for now)
        if Keyword.get(opts, :webhooks, true) and protocol == :ucp do
          post(
            "/webhooks/ucp",
            Bazaar.Phoenix.Controller,
            :webhook,
            assigns: assigns
          )
        end
      end
    end
  end
end
