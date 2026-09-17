import Config

config :flower_shop, FlowerShopWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [json: FlowerShopWeb.ErrorJSON], layout: false],
  secret_key_base: String.duplicate("flowershop", 8),
  server: config_env() != :test

config :phoenix, :json_library, Jason

config :logger, level: :info
