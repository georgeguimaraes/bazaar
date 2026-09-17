defmodule FlowerShopWeb.OrderController do
  use Phoenix.Controller, formats: [:json]

  import FlowerShopWeb.Responses, only: [reply: 2]

  alias FlowerShop.Handler

  def show(conn, %{"id" => id}), do: reply(conn, Handler.get_order(id, conn))

  def update(conn, %{"id" => id} = params), do: reply(conn, Handler.update_order(id, params))
end
