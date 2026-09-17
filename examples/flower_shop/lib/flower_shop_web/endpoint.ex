defmodule FlowerShopWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :flower_shop

  plug Plug.Parsers, parsers: [:json], pass: ["*/*"], json_decoder: Jason
  plug FlowerShopWeb.Router
end
