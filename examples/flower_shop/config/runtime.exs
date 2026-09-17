import Config

port = String.to_integer(System.get_env("PORT", "8182"))

config :flower_shop, FlowerShopWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: port],
  url: [host: "localhost", port: port]

config :flower_shop,
  base_url: System.get_env("FLOWER_SHOP_URL", "http://localhost:#{port}"),
  simulation_secret: System.get_env("SIMULATION_SECRET", "super-secret-sim-key")
