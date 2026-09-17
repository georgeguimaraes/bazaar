defmodule Bazaar.Plugs.IdempotencyTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Bazaar.Plugs.Idempotency

  # The same behaviour is expected from every store.
  @stores [:ets, :cachex]

  defp start_store(:ets) do
    table = :"idempotency_#{System.unique_integer([:positive])}"
    start_supervised!({Bazaar.Idempotency.ETS, name: table})
    {Bazaar.Idempotency.ETS, table}
  end

  defp start_store(:cachex) do
    cache = :"idempotency_#{System.unique_integer([:positive])}"
    start_supervised!({Cachex, [cache, []]})
    {Bazaar.Idempotency.Cachex, cache}
  end

  defp request(opts, key, body, method \\ :post) do
    conn = conn(method, "/checkout-sessions", body)
    conn = if key, do: put_req_header(conn, "idempotency-key", key), else: conn
    Idempotency.call(conn, opts)
  end

  defp respond(conn, status \\ 201) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, JSON.encode!(%{"id" => "chk_1", "nonce" => System.unique_integer()}))
  end

  for name <- @stores do
    describe "with the #{name} store" do
      setup do
        %{opts: Idempotency.init(store: start_store(unquote(name)))}
      end

      test "replays the first response for the same key and body", %{opts: opts} do
        first = respond(request(opts, "key-1", %{"currency" => "USD"}))
        replay = request(opts, "key-1", %{"currency" => "USD"})

        assert replay.halted
        assert replay.status == 201
        assert replay.resp_body == first.resp_body
        assert get_resp_header(replay, "idempotency-key") == ["key-1"]
      end

      test "conflicts when the same key carries a different body", %{opts: opts} do
        respond(request(opts, "key-2", %{"currency" => "USD"}))
        conflict = request(opts, "key-2", %{"currency" => "EUR"})

        assert conflict.halted
        assert conflict.status == 409

        assert [%{"code" => "idempotency_conflict"}] =
                 JSON.decode!(conflict.resp_body)["messages"]
      end

      test "refuses a concurrent duplicate while the first request is in flight", %{opts: opts} do
        in_flight = request(opts, "key-5", %{"currency" => "USD"})
        refute in_flight.halted

        duplicate = request(opts, "key-5", %{"currency" => "USD"})
        assert duplicate.status == 409

        assert [%{"code" => "idempotency_in_progress"}] =
                 JSON.decode!(duplicate.resp_body)["messages"]

        respond(in_flight)
        assert request(opts, "key-5", %{"currency" => "USD"}).status == 201
      end

      test "takes over a reservation left behind by a crashed request", %{opts: opts} do
        stale = Idempotency.init(store: opts.store, reservation_ttl: 0)
        request(stale, "key-6", %{})
        Process.sleep(1)

        refute request(stale, "key-6", %{}).halted
      end

      test "does not keep server errors, so the retry runs the action again", %{opts: opts} do
        respond(request(opts, "key-7", %{}), 500)

        refute request(opts, "key-7", %{}).halted
      end

      test "only records the configured methods and passes through without a key", %{opts: opts} do
        respond(request(opts, "key-3", %{}, :get))
        again = request(opts, "key-3", %{}, :get)
        refute again.halted
        assert again.assigns.idempotency_key == "key-3"

        conn = request(opts, nil, %{})
        refute conn.halted
        refute Map.has_key?(conn.assigns, :idempotency_key)
      end
    end
  end

  test "raises a helpful error when the ETS store is not running" do
    opts = Idempotency.init(store: {Bazaar.Idempotency.ETS, :missing_idempotency_table})

    assert_raise RuntimeError, ~r/add Bazaar.Idempotency.ETS/, fn ->
      request(opts, "key-4", %{})
    end
  end
end
