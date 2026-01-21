defmodule Bazaar.Phoenix.RouterTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  # Test handler with all capabilities
  defmodule FullHandler do
    use Bazaar.Handler

    @impl true
    def capabilities, do: [:checkout, :orders, :identity]

    @impl true
    def business_profile do
      %{
        "name" => "Test Store",
        "description" => "A test store"
      }
    end

    @impl true
    def create_checkout(params, _conn) do
      {:ok, Map.put(params, "id", "checkout_123")}
    end

    @impl true
    def get_checkout("found", _conn), do: {:ok, %{id: "found", status: :open}}
    def get_checkout("not_found", _conn), do: {:error, :not_found}
    def get_checkout(_, _conn), do: {:error, :not_found}

    @impl true
    def update_checkout("found", params, _conn), do: {:ok, Map.put(params, "id", "found")}
    def update_checkout("not_found", _params, _conn), do: {:error, :not_found}
    def update_checkout(_, _params, _conn), do: {:error, :not_found}

    @impl true
    def cancel_checkout("found", _conn), do: {:ok, %{id: "found", status: :cancelled}}
    def cancel_checkout("not_found", _conn), do: {:error, :not_found}
    def cancel_checkout(_, _conn), do: {:error, :not_found}

    @impl true
    def get_order("found", _conn), do: {:ok, %{id: "found", status: :confirmed}}
    def get_order("not_found", _conn), do: {:error, :not_found}
    def get_order(_, _conn), do: {:error, :not_found}

    @impl true
    def cancel_order("found", _conn), do: {:ok, %{id: "found", status: :cancelled}}
    def cancel_order("not_found", _conn), do: {:error, :not_found}
    def cancel_order(_, _conn), do: {:error, :not_found}

    @impl true
    def link_identity(%{"token" => _token} = params, _conn), do: {:ok, params}
    def link_identity(_params, _conn), do: {:error, :invalid_token}

    @impl true
    def handle_webhook(%{"event" => _event} = params), do: {:ok, params}
    def handle_webhook(_params), do: {:error, :invalid_webhook}
  end

  # Test handler with only checkout
  defmodule CheckoutOnlyHandler do
    use Bazaar.Handler

    @impl true
    def capabilities, do: [:checkout]

    @impl true
    def business_profile do
      %{"name" => "Checkout Only Store"}
    end

    @impl true
    def create_checkout(params, _conn), do: {:ok, params}

    @impl true
    def get_checkout(id, _conn), do: {:ok, %{id: id}}

    @impl true
    def update_checkout(id, params, _conn), do: {:ok, Map.put(params, "id", id)}

    @impl true
    def cancel_checkout(id, _conn), do: {:ok, %{id: id, status: :cancelled}}
  end

  # Router with full handler
  defmodule FullRouter do
    use Phoenix.Router
    use Bazaar.Phoenix.Router

    pipeline :api do
      plug(:accepts, ["json"])
    end

    scope "/" do
      pipe_through(:api)
      bazaar_routes("/", FullHandler)
    end
  end

  # Router with checkout only and custom path
  defmodule LimitedRouter do
    use Phoenix.Router
    use Bazaar.Phoenix.Router

    pipeline :api do
      plug(:accepts, ["json"])
    end

    scope "/" do
      pipe_through(:api)
      bazaar_routes("/api/v1", CheckoutOnlyHandler, only: [:checkout], webhooks: false)
    end
  end

  # Router without discovery
  defmodule NoDiscoveryRouter do
    use Phoenix.Router
    use Bazaar.Phoenix.Router

    pipeline :api do
      plug(:accepts, ["json"])
    end

    scope "/" do
      pipe_through(:api)
      bazaar_routes("/", FullHandler, discovery: false)
    end
  end

  describe "route generation" do
    test "generates discovery route" do
      routes = FullRouter.__routes__()
      discovery_route = Enum.find(routes, &(&1.path == "/.well-known/ucp"))

      assert discovery_route != nil
      assert discovery_route.verb == :get
      assert discovery_route.plug == Bazaar.Phoenix.Controller
      assert discovery_route.plug_opts == :discovery
    end

    test "generates checkout routes" do
      routes = FullRouter.__routes__()

      # POST /checkout-sessions
      create_route = Enum.find(routes, &(&1.path == "/checkout-sessions" and &1.verb == :post))
      assert create_route != nil
      assert create_route.plug_opts == :create_checkout

      # GET /checkout-sessions/:id
      get_route =
        Enum.find(routes, &(&1.path == "/checkout-sessions/:id" and &1.verb == :get))

      assert get_route != nil
      assert get_route.plug_opts == :get_checkout

      # PATCH /checkout-sessions/:id
      update_route =
        Enum.find(routes, &(&1.path == "/checkout-sessions/:id" and &1.verb == :patch))

      assert update_route != nil
      assert update_route.plug_opts == :update_checkout

      # DELETE /checkout-sessions/:id
      delete_route =
        Enum.find(routes, &(&1.path == "/checkout-sessions/:id" and &1.verb == :delete))

      assert delete_route != nil
      assert delete_route.plug_opts == :cancel_checkout
    end

    test "generates order routes" do
      routes = FullRouter.__routes__()

      # GET /orders/:id
      get_route = Enum.find(routes, &(&1.path == "/orders/:id" and &1.verb == :get))
      assert get_route != nil
      assert get_route.plug_opts == :get_order

      # POST /orders/:id/actions/cancel
      cancel_route =
        Enum.find(routes, &(&1.path == "/orders/:id/actions/cancel" and &1.verb == :post))

      assert cancel_route != nil
      assert cancel_route.plug_opts == :cancel_order
    end

    test "generates identity routes" do
      routes = FullRouter.__routes__()

      # POST /identity/link
      link_route = Enum.find(routes, &(&1.path == "/identity/link" and &1.verb == :post))
      assert link_route != nil
      assert link_route.plug_opts == :link_identity
    end

    test "generates webhook route" do
      routes = FullRouter.__routes__()

      webhook_route = Enum.find(routes, &(&1.path == "/webhooks/ucp" and &1.verb == :post))
      assert webhook_route != nil
      assert webhook_route.plug_opts == :webhook
    end

    test "respects :only option" do
      routes = LimitedRouter.__routes__()

      # Should have checkout routes
      assert Enum.any?(routes, &(&1.path == "/api/v1/checkout-sessions"))

      # Should NOT have order routes
      refute Enum.any?(routes, &String.contains?(&1.path, "/orders"))

      # Should NOT have identity routes
      refute Enum.any?(routes, &String.contains?(&1.path, "/identity"))
    end

    test "respects :webhooks option" do
      routes = LimitedRouter.__routes__()

      # Should NOT have webhook route
      refute Enum.any?(routes, &String.contains?(&1.path, "/webhooks"))
    end

    test "respects :discovery option" do
      routes = NoDiscoveryRouter.__routes__()

      # Should NOT have discovery route
      refute Enum.any?(routes, &String.contains?(&1.path, "/.well-known/ucp"))

      # Should still have other routes
      assert Enum.any?(routes, &(&1.path == "/checkout-sessions"))
    end

    test "applies custom path prefix" do
      routes = LimitedRouter.__routes__()

      discovery_route = Enum.find(routes, &String.contains?(&1.path, ".well-known"))
      assert discovery_route.path == "/api/v1/.well-known/ucp"

      checkout_route = Enum.find(routes, &String.ends_with?(&1.path, "/checkout-sessions"))
      assert checkout_route.path == "/api/v1/checkout-sessions"
    end
  end

  describe "controller actions" do
    setup do
      {:ok, conn: conn(:get, "/") |> put_req_header("accept", "application/json")}
    end

    test "discovery returns profile", %{conn: conn} do
      conn =
        conn
        |> Map.put(:host, "example.com")
        |> Map.put(:port, 443)
        |> Map.put(:scheme, :https)
        |> Plug.Conn.assign(:bazaar_handler, FullHandler)
        |> Bazaar.Phoenix.Controller.discovery(%{})

      assert conn.status == 200
      body = JSON.decode!(conn.resp_body)
      assert body["ucp"]["merchant"]["name"] == "Test Store"
      assert is_list(body["ucp"]["capabilities"])
    end

    test "create_checkout returns 201 on success", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:bazaar_handler, FullHandler)
        |> Bazaar.Phoenix.Controller.create_checkout(%{"currency" => "USD"})

      assert conn.status == 201
      body = JSON.decode!(conn.resp_body)
      assert body["id"] == "checkout_123"
      assert body["currency"] == "USD"
    end

    test "get_checkout returns checkout on success", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:bazaar_handler, FullHandler)
        |> Bazaar.Phoenix.Controller.get_checkout(%{"id" => "found"})

      assert conn.status == 200
      body = JSON.decode!(conn.resp_body)
      assert body["id"] == "found"
    end

    test "get_checkout returns 404 when not found", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:bazaar_handler, FullHandler)
        |> Bazaar.Phoenix.Controller.get_checkout(%{"id" => "not_found"})

      assert conn.status == 404
      body = JSON.decode!(conn.resp_body)
      assert body["error"] == "not_found"
      assert body["resource_id"] == "not_found"
    end

    test "update_checkout returns updated checkout", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:bazaar_handler, FullHandler)
        |> Bazaar.Phoenix.Controller.update_checkout(%{"id" => "found", "total" => "99.99"})

      assert conn.status == 200
      body = JSON.decode!(conn.resp_body)
      assert body["id"] == "found"
      assert body["total"] == "99.99"
    end

    test "update_checkout returns 404 when not found", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:bazaar_handler, FullHandler)
        |> Bazaar.Phoenix.Controller.update_checkout(%{"id" => "not_found", "total" => "99.99"})

      assert conn.status == 404
    end

    test "cancel_checkout returns cancelled checkout", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:bazaar_handler, FullHandler)
        |> Bazaar.Phoenix.Controller.cancel_checkout(%{"id" => "found"})

      assert conn.status == 200
      body = JSON.decode!(conn.resp_body)
      assert body["status"] == "cancelled"
    end

    test "get_order returns order on success", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:bazaar_handler, FullHandler)
        |> Bazaar.Phoenix.Controller.get_order(%{"id" => "found"})

      assert conn.status == 200
      body = JSON.decode!(conn.resp_body)
      assert body["id"] == "found"
    end

    test "get_order returns 404 when not found", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:bazaar_handler, FullHandler)
        |> Bazaar.Phoenix.Controller.get_order(%{"id" => "not_found"})

      assert conn.status == 404
      body = JSON.decode!(conn.resp_body)
      assert body["error"] == "not_found"
    end

    test "cancel_order returns cancelled order", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:bazaar_handler, FullHandler)
        |> Bazaar.Phoenix.Controller.cancel_order(%{"id" => "found"})

      assert conn.status == 200
      body = JSON.decode!(conn.resp_body)
      assert body["status"] == "cancelled"
    end

    test "link_identity returns result on success", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:bazaar_handler, FullHandler)
        |> Bazaar.Phoenix.Controller.link_identity(%{"token" => "abc123"})

      assert conn.status == 200
      body = JSON.decode!(conn.resp_body)
      assert body["token"] == "abc123"
    end

    test "link_identity returns error on failure", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:bazaar_handler, FullHandler)
        |> Bazaar.Phoenix.Controller.link_identity(%{})

      assert conn.status == 422
      body = JSON.decode!(conn.resp_body)
      assert body["error"] == "invalid_token"
    end

    test "webhook returns success on valid webhook", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:bazaar_handler, FullHandler)
        |> Bazaar.Phoenix.Controller.webhook(%{"event" => "order.created"})

      assert conn.status == 200
      body = JSON.decode!(conn.resp_body)
      assert body["status"] == "processed"
    end

    test "webhook returns error on invalid webhook", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:bazaar_handler, FullHandler)
        |> Bazaar.Phoenix.Controller.webhook(%{})

      assert conn.status == 422
      body = JSON.decode!(conn.resp_body)
      assert body["error"] == "invalid_webhook"
    end
  end

  # Router with ACP protocol
  defmodule AcpRouter do
    use Phoenix.Router
    use Bazaar.Phoenix.Router

    pipeline :api do
      plug(:accepts, ["json"])
    end

    scope "/" do
      pipe_through(:api)
      bazaar_routes("/acp", FullHandler, protocol: :acp)
    end
  end

  # Router with both protocols
  defmodule DualProtocolRouter do
    use Phoenix.Router
    use Bazaar.Phoenix.Router

    pipeline :api do
      plug(:accepts, ["json"])
    end

    scope "/" do
      pipe_through(:api)
      bazaar_routes("/ucp", FullHandler, protocol: :ucp)
      bazaar_routes("/acp", FullHandler, protocol: :acp)
    end
  end

  describe "ACP route generation" do
    test "generates ACP checkout routes with underscores" do
      routes = AcpRouter.__routes__()

      # POST /checkout_sessions (underscore, not hyphen)
      create_route =
        Enum.find(routes, &(&1.path == "/acp/checkout_sessions" and &1.verb == :post))

      assert create_route != nil
      assert create_route.plug_opts == :create_checkout

      # GET /checkout_sessions/:id
      get_route =
        Enum.find(routes, &(&1.path == "/acp/checkout_sessions/:id" and &1.verb == :get))

      assert get_route != nil
      assert get_route.plug_opts == :get_checkout

      # POST /checkout_sessions/:id (update via POST, not PATCH)
      update_route =
        Enum.find(
          routes,
          &(&1.path == "/acp/checkout_sessions/:id" and &1.verb == :post and
              &1.plug_opts == :update_checkout)
        )

      assert update_route != nil
    end

    test "generates ACP complete route without /actions/" do
      routes = AcpRouter.__routes__()

      # POST /checkout_sessions/:id/complete (not /actions/complete)
      complete_route =
        Enum.find(
          routes,
          &(&1.path == "/acp/checkout_sessions/:id/complete" and &1.verb == :post)
        )

      assert complete_route != nil
      assert complete_route.plug_opts == :complete_checkout
    end

    test "generates ACP cancel route as POST" do
      routes = AcpRouter.__routes__()

      # POST /checkout_sessions/:id/cancel (not DELETE)
      cancel_route =
        Enum.find(routes, &(&1.path == "/acp/checkout_sessions/:id/cancel" and &1.verb == :post))

      assert cancel_route != nil
      assert cancel_route.plug_opts == :cancel_checkout
    end

    test "does not generate discovery route for ACP" do
      routes = AcpRouter.__routes__()

      discovery_route = Enum.find(routes, &String.contains?(&1.path, ".well-known"))
      assert discovery_route == nil
    end

    test "routes connect to the controller for ACP" do
      routes = AcpRouter.__routes__()

      create_route =
        Enum.find(routes, &(&1.path == "/acp/checkout_sessions" and &1.verb == :post))

      assert create_route.plug == Bazaar.Phoenix.Controller
      assert create_route.plug_opts == :create_checkout
    end
  end

  describe "dual protocol routing" do
    test "generates both UCP and ACP routes" do
      routes = DualProtocolRouter.__routes__()

      # UCP routes with hyphens
      ucp_create = Enum.find(routes, &(&1.path == "/ucp/checkout-sessions" and &1.verb == :post))
      assert ucp_create != nil

      # ACP routes with underscores
      acp_create = Enum.find(routes, &(&1.path == "/acp/checkout_sessions" and &1.verb == :post))
      assert acp_create != nil
    end

    test "UCP uses PATCH for update, ACP uses POST" do
      routes = DualProtocolRouter.__routes__()

      # UCP: PATCH /checkout-sessions/:id
      ucp_update =
        Enum.find(
          routes,
          &(&1.path == "/ucp/checkout-sessions/:id" and &1.verb == :patch and
              &1.plug_opts == :update_checkout)
        )

      assert ucp_update != nil

      # ACP: POST /checkout_sessions/:id
      acp_update =
        Enum.find(
          routes,
          &(&1.path == "/acp/checkout_sessions/:id" and &1.verb == :post and
              &1.plug_opts == :update_checkout)
        )

      assert acp_update != nil
    end

    test "UCP uses DELETE for cancel, ACP uses POST" do
      routes = DualProtocolRouter.__routes__()

      # UCP: DELETE /checkout-sessions/:id
      ucp_cancel =
        Enum.find(routes, &(&1.path == "/ucp/checkout-sessions/:id" and &1.verb == :delete))

      assert ucp_cancel != nil

      # ACP: POST /checkout_sessions/:id/cancel
      acp_cancel =
        Enum.find(routes, &(&1.path == "/acp/checkout_sessions/:id/cancel" and &1.verb == :post))

      assert acp_cancel != nil
    end

    test "only UCP has discovery endpoint" do
      routes = DualProtocolRouter.__routes__()

      ucp_discovery = Enum.find(routes, &(&1.path == "/ucp/.well-known/ucp"))
      assert ucp_discovery != nil

      acp_discovery =
        Enum.find(
          routes,
          &(&1.path == "/acp/.well-known/ucp" or &1.path == "/acp/.well-known/acp")
        )

      assert acp_discovery == nil
    end
  end

  describe "ACP protocol transformation" do
    setup do
      {:ok, conn: conn(:get, "/") |> put_req_header("accept", "application/json")}
    end

    test "transforms ACP request to internal format", %{conn: conn} do
      # ACP request with line_items
      acp_params = %{
        "line_items" => [
          %{
            "product" => %{"name" => "Test Product", "id" => "SKU-001"},
            "quantity" => 2,
            "base_amount" => 1000
          }
        ],
        "currency" => "USD"
      }

      conn =
        conn
        |> Plug.Conn.assign(:bazaar_handler, FullHandler)
        |> Plug.Conn.assign(:bazaar_protocol, :acp)
        |> Bazaar.Phoenix.Controller.create_checkout(acp_params)

      assert conn.status == 201
      body = JSON.decode!(conn.resp_body)

      # Verify the handler received transformed internal format
      assert body["id"] == "checkout_123"
      # Response should be in ACP format with line_items
      assert is_list(body["line_items"]) or body["items"] != nil
    end

    test "transforms response status for ACP protocol", %{conn: conn} do
      # Handler that returns UCP status
      defmodule StatusTestHandler do
        use Bazaar.Handler

        @impl true
        def capabilities, do: [:checkout]

        @impl true
        def business_profile, do: %{"name" => "Status Test"}

        @impl true
        def get_checkout(_id, _conn) do
          {:ok, %{"id" => "test", "status" => "incomplete"}}
        end
      end

      conn =
        conn
        |> Plug.Conn.assign(:bazaar_handler, StatusTestHandler)
        |> Plug.Conn.assign(:bazaar_protocol, :acp)
        |> Bazaar.Phoenix.Controller.get_checkout(%{"id" => "test"})

      assert conn.status == 200
      body = JSON.decode!(conn.resp_body)

      # Status should be transformed to ACP format
      assert body["status"] == "not_ready_for_payment"
    end

    test "UCP protocol passes through unchanged", %{conn: conn} do
      defmodule UcpPassthroughHandler do
        use Bazaar.Handler

        @impl true
        def capabilities, do: [:checkout]

        @impl true
        def business_profile, do: %{"name" => "UCP Test"}

        @impl true
        def get_checkout(_id, _conn) do
          {:ok, %{"id" => "test", "status" => "incomplete"}}
        end
      end

      conn =
        conn
        |> Plug.Conn.assign(:bazaar_handler, UcpPassthroughHandler)
        |> Plug.Conn.assign(:bazaar_protocol, :ucp)
        |> Bazaar.Phoenix.Controller.get_checkout(%{"id" => "test"})

      assert conn.status == 200
      body = JSON.decode!(conn.resp_body)

      # Status should remain in UCP format
      assert body["status"] == "incomplete"
    end
  end

  describe "base_url generation" do
    test "uses https scheme and host" do
      conn =
        conn(:get, "/")
        |> Map.put(:host, "api.example.com")
        |> Map.put(:port, 443)
        |> Map.put(:scheme, :https)
        |> put_req_header("accept", "application/json")
        |> Plug.Conn.assign(:bazaar_handler, FullHandler)
        |> Bazaar.Phoenix.Controller.discovery(%{})

      body = JSON.decode!(conn.resp_body)
      endpoint = body["ucp"]["services"]["dev.ucp.shopping"]["rest"]["endpoint"]
      assert endpoint == "https://api.example.com"
    end

    test "includes port for non-standard ports" do
      conn =
        conn(:get, "/")
        |> Map.put(:host, "localhost")
        |> Map.put(:port, 4000)
        |> Map.put(:scheme, :http)
        |> put_req_header("accept", "application/json")
        |> Plug.Conn.assign(:bazaar_handler, FullHandler)
        |> Bazaar.Phoenix.Controller.discovery(%{})

      body = JSON.decode!(conn.resp_body)
      endpoint = body["ucp"]["services"]["dev.ucp.shopping"]["rest"]["endpoint"]
      assert endpoint == "http://localhost:4000"
    end
  end
end
