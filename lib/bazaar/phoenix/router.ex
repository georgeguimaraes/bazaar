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
      capabilities = Keyword.get(opts, :only, handler.capabilities())

      scope path do
        Bazaar.Phoenix.Router.mount_discovery(protocol, assigns, opts)
        Bazaar.Phoenix.Router.mount_checkout(protocol, assigns, capabilities)
        Bazaar.Phoenix.Router.mount_ucp_only(protocol, assigns, capabilities, opts)
      end
    end
  end

  @doc false
  defmacro mount_discovery(protocol, assigns, opts) do
    quote do
      if unquote(protocol) == :ucp and Keyword.get(unquote(opts), :discovery, true) do
        get("/.well-known/ucp", Bazaar.Phoenix.Controller, :discovery, assigns: unquote(assigns))
      end
    end
  end

  @doc false
  defmacro mount_checkout(protocol, assigns, capabilities) do
    quote do
      if :checkout in unquote(capabilities) do
        case unquote(protocol) do
          :ucp -> Bazaar.Phoenix.Router.ucp_checkout_routes(unquote(assigns))
          :acp -> Bazaar.Phoenix.Router.acp_checkout_routes(unquote(assigns))
        end
      end
    end
  end

  @doc false
  defmacro ucp_checkout_routes(assigns) do
    quote do
      post("/checkout-sessions", Bazaar.Phoenix.Controller, :create_checkout,
        assigns: unquote(assigns)
      )

      get("/checkout-sessions/:id", Bazaar.Phoenix.Controller, :get_checkout,
        assigns: unquote(assigns)
      )

      patch("/checkout-sessions/:id", Bazaar.Phoenix.Controller, :update_checkout,
        assigns: unquote(assigns)
      )

      post(
        "/checkout-sessions/:id/actions/complete",
        Bazaar.Phoenix.Controller,
        :complete_checkout,
        assigns: unquote(assigns)
      )

      delete("/checkout-sessions/:id", Bazaar.Phoenix.Controller, :cancel_checkout,
        assigns: unquote(assigns)
      )
    end
  end

  @doc false
  defmacro acp_checkout_routes(assigns) do
    quote do
      post("/checkout_sessions", Bazaar.Phoenix.Controller, :create_checkout,
        assigns: unquote(assigns)
      )

      get("/checkout_sessions/:id", Bazaar.Phoenix.Controller, :get_checkout,
        assigns: unquote(assigns)
      )

      post("/checkout_sessions/:id", Bazaar.Phoenix.Controller, :update_checkout,
        assigns: unquote(assigns)
      )

      post("/checkout_sessions/:id/complete", Bazaar.Phoenix.Controller, :complete_checkout,
        assigns: unquote(assigns)
      )

      post("/checkout_sessions/:id/cancel", Bazaar.Phoenix.Controller, :cancel_checkout,
        assigns: unquote(assigns)
      )
    end
  end

  @doc false
  defmacro mount_ucp_only(protocol, assigns, capabilities, opts) do
    quote do
      if unquote(protocol) == :ucp do
        Bazaar.Phoenix.Router.mount_orders(unquote(assigns), unquote(capabilities))
        Bazaar.Phoenix.Router.mount_identity(unquote(assigns), unquote(capabilities))
        Bazaar.Phoenix.Router.mount_catalog(unquote(assigns), unquote(capabilities))
        Bazaar.Phoenix.Router.mount_webhooks(unquote(assigns), unquote(opts))
      end
    end
  end

  @doc false
  defmacro mount_orders(assigns, capabilities) do
    quote do
      if :orders in unquote(capabilities) do
        get("/orders/:id", Bazaar.Phoenix.Controller, :get_order, assigns: unquote(assigns))

        post("/orders/:id/actions/cancel", Bazaar.Phoenix.Controller, :cancel_order,
          assigns: unquote(assigns)
        )
      end
    end
  end

  @doc false
  defmacro mount_identity(assigns, capabilities) do
    quote do
      if :identity in unquote(capabilities) do
        post("/identity/link", Bazaar.Phoenix.Controller, :link_identity,
          assigns: unquote(assigns)
        )
      end
    end
  end

  @doc false
  defmacro mount_catalog(assigns, capabilities) do
    quote do
      if :catalog in unquote(capabilities) do
        get("/products", Bazaar.Phoenix.Controller, :list_products, assigns: unquote(assigns))

        get("/products/search", Bazaar.Phoenix.Controller, :search_products,
          assigns: unquote(assigns)
        )

        get("/products/:id", Bazaar.Phoenix.Controller, :get_product, assigns: unquote(assigns))
      end
    end
  end

  @doc false
  defmacro mount_webhooks(assigns, opts) do
    quote do
      if Keyword.get(unquote(opts), :webhooks, true) do
        post("/webhooks/ucp", Bazaar.Phoenix.Controller, :webhook, assigns: unquote(assigns))
      end
    end
  end
end
