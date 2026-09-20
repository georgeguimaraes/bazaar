defmodule Bazaar.Plugs.UCPTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Bazaar.Signing.{HttpSignature, Key}

  # A platform whose profile publishes the key it signs with.
  @platform_profile "https://platform.test/.well-known/ucp"
  @platform_key Key.generate(:p256)
  @shop_key Key.generate(:ed25519)

  defmodule Shop do
    use Bazaar.Shop

    @impl true
    def base_url, do: "https://shop.test"

    @impl true
    def item(_id), do: %{item: %{"title" => "Roses", "price" => 3500}, stock: nil}

    @impl true
    def http_client, do: Process.get(:http_client)

    @impl true
    def signing_key, do: Process.get(:shop_key)
  end

  defmodule Handler do
    use Bazaar.Handler, shop: Shop, store: Bazaar.Store.ETS

    @impl true
    def capabilities, do: [:checkout]
  end

  defmodule Router do
    use Phoenix.Router
    use Bazaar.Phoenix.Router

    pipeline :ucp do
      plug(Bazaar.Plugs.UCP)
    end

    pipeline :bare do
      plug(Bazaar.Plugs.UCP, verify_signatures: false, sign_responses: false)
    end

    scope "/" do
      pipe_through(:ucp)
      bazaar_routes("/", Handler)
    end

    scope "/bare" do
      pipe_through(:bare)
      bazaar_routes("/", Handler)
    end
  end

  @body ~s({"currency":"USD","line_items":[{"item":{"id":"roses"}}]})

  setup do
    # The shop's client serves the platform's profile, which is how the
    # pipeline learns the keys to verify against.
    profile = %{"ucp" => %{"version" => "2026-08-25"}, "keys" => [Key.public_jwk(@platform_key)]}

    Process.put(:http_client, %{
      get: fn @platform_profile -> {:ok, %{status: 200, body: profile}} end,
      post: fn _url, _body, _headers -> {:error, :not_used} end
    })

    Process.put(:shop_key, @shop_key)
    :ok
  end

  defp request(path, headers) do
    conn = conn(:post, path, @body) |> put_private(:bazaar_raw_body, @body)

    headers
    |> Enum.reduce(conn, fn {name, value}, conn -> put_req_header(conn, name, value) end)
    |> Router.call(Router.init([]))
  end

  defp signed_headers(path, extra \\ []) do
    headers =
      [
        {"content-type", "application/json"},
        {"ucp-agent", ~s(profile="#{@platform_profile}")}
      ] ++ extra

    HttpSignature.sign(
      %{method: "POST", url: "http://www.example.com#{path}", headers: headers, body: @body},
      @platform_key,
      components: ["ucp-agent"]
    )
  end

  test "negotiates the version, verifies a signed request and signs the answer" do
    conn = request("/checkout-sessions", signed_headers("/checkout-sessions"))

    assert conn.status == 201
    assert conn.assigns.ucp_agent_profile == @platform_profile
    assert conn.assigns.ucp_signature.keyid == @platform_key.kid

    response = %{
      status: conn.status,
      headers:
        Enum.filter(conn.resp_headers, fn {n, _} ->
          n in ~w(content-type content-digest signature-input signature)
        end),
      body: conn.resp_body
    }

    assert {:ok, %{keyid: keyid}} = HttpSignature.verify_response(response, @shop_key)
    assert keyid == @shop_key.kid
  end

  test "rejects a request signed by a key the platform doesn't publish" do
    headers =
      HttpSignature.sign(
        %{
          method: "POST",
          url: "http://www.example.com/checkout-sessions",
          headers: [
            {"content-type", "application/json"},
            {"ucp-agent", ~s(profile="#{@platform_profile}")}
          ],
          body: @body
        },
        Key.generate(:p256)
      )

    conn = request("/checkout-sessions", headers)
    assert conn.status == 401

    assert JSON.decode!(conn.resp_body)["messages"] |> hd() |> Map.get("code") ==
             "invalid_signature"
  end

  test "lets unsigned requests through, still signing the answer" do
    conn = request("/checkout-sessions", [{"content-type", "application/json"}])
    assert conn.status == 201
    refute Map.has_key?(conn.assigns, :ucp_signature)
    assert [_] = get_resp_header(conn, "signature")
  end

  test "answers unsigned when the shop has no key" do
    Process.put(:shop_key, nil)
    conn = request("/checkout-sessions", [{"content-type", "application/json"}])
    assert conn.status == 201
    assert get_resp_header(conn, "signature") == []
  end

  test "rejects an unsupported protocol version before anything else runs" do
    headers = [{"ucp-agent", ~s(profile="#{@platform_profile}"; version="2099-01-01")}]
    conn = request("/checkout-sessions", headers)

    assert conn.status == 422
    assert get_resp_header(conn, "signature") == []
  end

  test "replays an idempotent repeat with the signature it first answered with" do
    headers = [{"content-type", "application/json"}, {"idempotency-key", "ucp-plug-1"}]
    first = request("/checkout-sessions", headers)
    replay = request("/checkout-sessions", headers)

    assert replay.status == first.status
    assert replay.resp_body == first.resp_body
    assert get_resp_header(replay, "signature") == get_resp_header(first, "signature")
  end

  test "both steps can be switched off" do
    conn = request("/bare/checkout-sessions", signed_headers("/bare/checkout-sessions"))

    assert conn.status == 201
    refute Map.has_key?(conn.assigns, :ucp_signature)
    assert get_resp_header(conn, "signature") == []
  end
end
