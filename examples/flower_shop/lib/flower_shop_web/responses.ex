defmodule FlowerShopWeb.Responses do
  @moduledoc """
  Turns handler results into HTTP responses. Errors use the UCP error
  response document: a `ucp` envelope with `status: "error"` and `messages`.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  def reply(conn, result, ok_status \\ 200)

  def reply(conn, {:ok, document}, ok_status), do: conn |> put_status(ok_status) |> json(document)

  def reply(conn, {:error, :not_found}, _),
    do: error(conn, 404, "not_found", "Resource not found")

  def reply(conn, {:error, :invalid_state}, _) do
    error(conn, 409, "invalid_state", "The checkout is no longer open for this action")
  end

  def reply(conn, {:error, :invalid_adjustments}, _) do
    error(
      conn,
      422,
      "invalid_request",
      "adjustments must be a list of entries with a valid status"
    )
  end

  def error(conn, status, code, content) do
    conn |> put_status(status) |> json(error_document(code, content))
  end

  def error_document(code, content) do
    %{
      "ucp" => %{"version" => Bazaar.DiscoveryProfile.version(), "status" => "error"},
      "messages" => [
        %{"type" => "error", "code" => code, "content" => content, "severity" => "unrecoverable"}
      ]
    }
  end
end
