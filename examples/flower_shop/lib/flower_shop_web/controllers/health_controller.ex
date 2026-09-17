defmodule FlowerShopWeb.HealthController do
  use Phoenix.Controller, formats: [:json]

  def show(conn, _params), do: json(conn, %{"status" => "ok"})
end
