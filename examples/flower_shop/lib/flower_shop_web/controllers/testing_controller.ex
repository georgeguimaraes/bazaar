defmodule FlowerShopWeb.TestingController do
  @moduledoc """
  Test-only hooks the conformance suite drives, guarded by the
  `Simulation-Secret` header so they can't be triggered by anyone else.
  """

  use Phoenix.Controller, formats: [:json]

  import FlowerShopWeb.Responses, only: [error: 4]

  alias FlowerShop.Handler

  plug :require_secret

  def simulate_shipping(conn, %{"order_id" => id}) do
    case Handler.ship_order(id) do
      {:ok, _order} -> json(conn, %{"status" => "ok"})
      {:error, :not_found} -> error(conn, 404, "not_found", "Order #{id} not found")
    end
  end

  defp require_secret(conn, _opts) do
    expected = Application.fetch_env!(:flower_shop, :simulation_secret)

    case get_req_header(conn, "simulation-secret") do
      [^expected] ->
        conn

      _ ->
        conn
        |> error(403, "forbidden", "A valid Simulation-Secret header is required")
        |> halt()
    end
  end
end
