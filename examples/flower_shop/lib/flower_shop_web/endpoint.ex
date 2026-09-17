defmodule FlowerShopWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :flower_shop

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["*/*"],
    json_decoder: Jason,
    body_reader: {Bazaar.Plugs.RawBody, :read_body, []}

  plug FlowerShopWeb.Router
end
