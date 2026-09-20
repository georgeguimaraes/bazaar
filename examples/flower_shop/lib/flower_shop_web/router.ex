defmodule FlowerShopWeb.Router do
  @moduledoc """
  `bazaar_routes` mounts every UCP route for the handler, behind the one plug
  that negotiates versions, replays idempotent requests, verifies inbound
  signatures and signs the answers. The app adds the two routes the
  conformance suite drives that aren't part of UCP at all.
  """

  use Phoenix.Router
  use Bazaar.Phoenix.Router

  pipeline :ucp do
    plug :accepts, ["json"]
    plug Bazaar.Plugs.UCP
  end

  scope "/" do
    pipe_through :ucp

    bazaar_routes("/", FlowerShop.Handler, webhooks: false, order_updates: true)

    scope "/", FlowerShopWeb do
      get "/healthz", HealthController, :show
      post "/testing/simulate-shipping/:order_id", TestingController, :simulate_shipping
    end
  end
end
