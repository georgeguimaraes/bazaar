defmodule Bazaar.Plugs.VerifySignatureTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Bazaar.Plugs.VerifySignature
  alias Bazaar.Signing.{HttpSignature, Key}

  @profile_url "https://platform.example/.well-known/ucp"
  @body ~s({"currency":"USD"})

  # A profile served by the platform, with its keys where the schema puts them.
  defp profile(key, where \\ :root) do
    jwk = Key.public_jwk(key)

    case where do
      :root -> %{"ucp" => %{"version" => "2026-08-25"}, "keys" => [jwk]}
      :ucp -> %{"ucp" => %{"version" => "2026-08-25", "keys" => [jwk]}}
    end
  end

  defp client(profile), do: fn @profile_url -> {:ok, %{status: 200, body: profile}} end

  # Signs the way a platform would: over the same method, URL, headers and raw body the conn carries.
  defp signed_conn(key, opts \\ []) do
    headers = [
      {"content-type", "application/json"},
      {"ucp-agent", ~s(profile="#{@profile_url}")},
      {"idempotency-key", "key-1"}
    ]

    signed =
      HttpSignature.sign(
        %{
          method: "POST",
          url: "http://www.example.com:80/checkout-sessions",
          headers: headers,
          body: @body
        },
        key,
        [components: ["idempotency-key", "ucp-agent"]] ++ opts
      )

    conn = conn(:post, "/checkout-sessions", @body) |> put_private(:bazaar_raw_body, @body)

    signed
    |> Enum.reduce(conn, fn {name, value}, conn -> put_req_header(conn, name, value) end)
    |> assign(:ucp_agent_profile, @profile_url)
  end

  defp verify(conn, client, opts \\ []) do
    VerifySignature.call(conn, VerifySignature.init([http_client: client] ++ opts))
  end

  defp error_code(conn),
    do: conn.resp_body |> JSON.decode!() |> get_in(["messages", Access.at(0), "code"])

  test "accepts a valid signature and records who signed" do
    key = Key.generate(:p256)
    conn = verify(signed_conn(key), client(profile(key)))

    refute conn.halted
    assert conn.assigns.ucp_signature.keyid == key.kid
  end

  test "finds keys published under ucp.keys as well" do
    key = Key.generate(:ed25519)
    refute verify(signed_conn(key), client(profile(key, :ucp))).halted
  end

  test "rejects a tampered body, a stale signature and a signer with no usable key" do
    key = Key.generate(:p256)

    tampered = signed_conn(key) |> put_private(:bazaar_raw_body, ~s({"currency":"EUR"}))
    assert verify(tampered, client(profile(key))).status == 401
    assert error_code(verify(tampered, client(profile(key)))) == "invalid_signature"

    stale = signed_conn(key, created: System.os_time(:second) - 3_600)
    assert error_code(verify(stale, client(profile(key)))) == "invalid_signature"

    other = Key.generate(:p256)
    assert error_code(verify(signed_conn(key), client(profile(other)))) == "invalid_signature"

    unreachable = fn _url -> {:error, :econnrefused} end
    assert error_code(verify(signed_conn(key), unreachable)) == "signer_unknown"
  end

  test "lets unsigned requests through unless required" do
    unsigned = conn(:post, "/checkout-sessions", @body) |> put_private(:bazaar_raw_body, @body)
    never_called = fn _url -> flunk("profile fetched for an unsigned request") end

    refute verify(unsigned, never_called).halted

    required = verify(unsigned, never_called, required: true)
    assert required.status == 401
    assert error_code(required) == "signature_required"
  end

  test "fetches a platform's profile once when given a cache" do
    key = Key.generate(:p256)
    {:ok, store} = Agent.start_link(fn -> %{} end)

    cache = %{
      get: fn k ->
        Agent.get(store, &Map.fetch(&1, k)) |> then(&if(&1 == :error, do: :miss, else: &1))
      end,
      put: fn k, v -> Agent.update(store, &Map.put(&1, k, v)) end
    }

    {:ok, counter} = Agent.start_link(fn -> 0 end)

    counting = fn @profile_url ->
      Agent.update(counter, &(&1 + 1))
      {:ok, %{status: 200, body: profile(key)}}
    end

    refute verify(signed_conn(key), counting, cache: cache).halted
    refute verify(signed_conn(key), counting, cache: cache).halted
    assert Agent.get(counter, & &1) == 1
  end

  test "explains when the raw body reader is missing" do
    key = Key.generate(:p256)
    conn = signed_conn(key) |> Map.update!(:private, &Map.delete(&1, :bazaar_raw_body))

    assert_raise RuntimeError, ~r/Bazaar.Plugs.RawBody/, fn ->
      verify(conn, client(profile(key)))
    end
  end

  test "takes the authority from the Host header and the scheme from the proxy" do
    key = Key.generate(:p256)

    headers = [
      {"content-type", "application/json"},
      {"host", "shop.example:4000"},
      {"x-forwarded-proto", "https"}
    ]

    signed =
      HttpSignature.sign(
        %{
          method: "POST",
          url: "https://shop.example:4000/checkout-sessions",
          headers: headers,
          body: @body
        },
        key
      )

    # Plug.Test won't accept a host header; adapters fill conn.host and conn.port from it.
    conn =
      signed
      |> Enum.reject(&(elem(&1, 0) == "host"))
      |> Enum.reduce(
        %{conn(:post, "/checkout-sessions", @body) | host: "shop.example", port: 4000},
        fn {name, value}, conn ->
          put_req_header(conn, name, value)
        end
      )
      |> put_private(:bazaar_raw_body, @body)
      |> assign(:ucp_agent_profile, @profile_url)

    refute verify(conn, client(profile(key))).halted
  end
end
