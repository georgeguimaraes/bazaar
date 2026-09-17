defmodule FlowerShopWeb.Responses do
  @moduledoc """
  Turns handler results into HTTP responses for the app's own routes; bazaar's
  controller does the same for the routes `bazaar_routes` mounts.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def reply(conn, result, ok_status \\ 200)

  def reply(conn, {:ok, document}, ok_status), do: conn |> put_status(ok_status) |> json(document)

  def reply(conn, {:error, :not_found}, _), do: error(conn, 404, :not_found)

  def reply(conn, {:error, :invalid_state}, _), do: error(conn, 409, :invalid_state)

  def reply(conn, {:error, :invalid_adjustments}, _) do
    error(conn, 422, "adjustments must be a list of entries with a valid status")
  end

  def error(conn, status, reason) do
    conn |> put_status(status) |> json(Bazaar.Errors.response(reason))
  end
end
