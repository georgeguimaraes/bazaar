defmodule FlowerShopWeb.Router do
  @moduledoc """
  `bazaar_routes` mounts discovery, checkout and order routes for the handler
  behind bazaar's header and idempotency plugs. The app adds the two routes
  the conformance suite drives that aren't part of UCP at all.
  """

  use Phoenix.Router
  use Bazaar.Phoenix.Router

  pipeline :ucp do
    plug :accepts, ["json"]
    plug Bazaar.Plugs.UCP
    plug Bazaar.Plugs.VerifySignature, http_client: &FlowerShop.Http.get/1

    plug Bazaar.Plugs.SignResponse, key: &FlowerShop.Shop.signing_key/0
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
