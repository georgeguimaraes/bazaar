defmodule FlowerShopWeb.Router do
  @moduledoc """
  `bazaar_routes` mounts discovery, checkout and order routes for the handler.
  The app adds the pipeline it wants in front of them (protocol headers,
  version negotiation, idempotent replay) and the few routes the conformance
  suite needs that the UCP REST binding doesn't define.
  """

  use Phoenix.Router
  use Bazaar.Phoenix.Router

  pipeline :ucp do
    plug :accepts, ["json"]
    plug Bazaar.Plugs.UCPHeaders
    plug FlowerShopWeb.Plugs.UcpVersion
    plug FlowerShopWeb.Plugs.Idempotency
  end

  scope "/" do
    pipe_through :ucp

    bazaar_routes("/", FlowerShop.Handler, webhooks: false)

    scope "/", FlowerShopWeb do
      get "/healthz", HealthController, :show
      put "/orders/:id", OrderController, :update
      post "/testing/simulate-shipping/:order_id", TestingController, :simulate_shipping
    end
  end
end
