defmodule FlowerShopWeb.Responses do
  @moduledoc "Error responses for the app's own routes, in the UCP error document shape."

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def error(conn, status, reason) do
    conn |> put_status(status) |> json(Bazaar.Errors.response(reason))
  end
end
