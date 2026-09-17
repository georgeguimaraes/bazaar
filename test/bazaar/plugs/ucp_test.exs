defmodule Bazaar.Plugs.UCPTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Bazaar.Plugs.UCP

  setup do
    table = :"ucp_plug_#{System.unique_integer([:positive])}"
    start_supervised!({Bazaar.Idempotency.ETS, name: table})
    %{opts: UCP.init(store: {Bazaar.Idempotency.ETS, table})}
  end

  test "runs headers then idempotency with shared options", %{opts: opts} do
    request = fn ->
      :post
      |> conn("/checkout-sessions", %{"currency" => "USD"})
      |> put_req_header("ucp-agent", ~s(profile="https://p.example/profile.json"))
      |> put_req_header("idempotency-key", "ucp-key-1")
      |> UCP.call(opts)
    end

    first = request.()
    assert first.assigns.ucp_agent_profile == "https://p.example/profile.json"
    assert first.assigns.idempotency_key == "ucp-key-1"
    refute first.halted

    first |> put_resp_content_type("application/json") |> send_resp(201, "{}")

    replay = request.()
    assert replay.halted
    assert replay.status == 201
  end

  test "forwards version: false to the headers plug", %{opts: opts} do
    rejected =
      :get
      |> conn("/checkout-sessions/1")
      |> put_req_header("ucp-agent", ~s(version="2099-01-01"))
      |> UCP.call(opts)

    assert rejected.status == 422

    allowed =
      :get
      |> conn("/checkout-sessions/1")
      |> put_req_header("ucp-agent", ~s(version="2099-01-01"))
      |> UCP.call(UCP.init(store: opts.idempotency.store, version: false))

    refute allowed.halted
  end
end
