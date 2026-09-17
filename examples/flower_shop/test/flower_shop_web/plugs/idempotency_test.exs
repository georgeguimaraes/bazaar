defmodule FlowerShopWeb.Plugs.IdempotencyTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias FlowerShopWeb.Plugs.Idempotency

  defp request(key, body) do
    :post
    |> conn("/checkout-sessions", body)
    |> put_req_header("idempotency-key", key)
    |> Idempotency.call([])
  end

  defp respond(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(201, Jason.encode!(%{"id" => "chk_1", "at" => System.unique_integer()}))
  end

  test "replays the stored response for the same key and body" do
    key = "key-" <> FlowerShop.Checkout.uuid()
    first = respond(request(key, %{"currency" => "USD"}))
    replay = request(key, %{"currency" => "USD"})

    assert replay.halted
    assert replay.status == 201
    assert replay.resp_body == first.resp_body
  end

  test "conflicts when the same key carries a different body" do
    key = "key-" <> FlowerShop.Checkout.uuid()
    respond(request(key, %{"currency" => "USD"}))
    conflict = request(key, %{"currency" => "EUR"})

    assert conflict.halted
    assert conflict.status == 409

    assert %{"messages" => [%{"code" => "idempotency_conflict"}]} =
             Jason.decode!(conflict.resp_body)
  end
end
