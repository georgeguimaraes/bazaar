defmodule Bazaar.Plugs.UCPHeadersTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  alias Bazaar.Plugs.UCPHeaders

  describe "init/1" do
    test "defaults the negotiated version to the library's spec version" do
      assert UCPHeaders.init([]) == %{version: Bazaar.DiscoveryProfile.version()}
      assert UCPHeaders.init(version: false) == %{version: false}
    end
  end

  describe "call/2 header extraction" do
    test "extracts ucp-agent header" do
      conn =
        conn(:post, "/checkout-sessions")
        |> put_req_header("ucp-agent", "google-shopping-agent/1.0")
        |> UCPHeaders.call([])

      assert conn.assigns[:ucp_agent] == "google-shopping-agent/1.0"
    end

    test "extracts ucp-request-id header" do
      conn =
        conn(:post, "/checkout-sessions")
        |> put_req_header("ucp-request-id", "req_abc123")
        |> UCPHeaders.call([])

      assert conn.assigns[:ucp_request_id] == "req_abc123"
    end

    test "extracts request-signature header" do
      conn =
        conn(:post, "/checkout-sessions")
        |> put_req_header("request-signature", "sha256=abc123...")
        |> UCPHeaders.call([])

      assert conn.assigns[:ucp_signature] == "sha256=abc123..."
    end

    test "extracts all headers together" do
      conn =
        conn(:post, "/checkout-sessions")
        |> put_req_header("ucp-agent", "test-agent/1.0")
        |> put_req_header("ucp-request-id", "req_xyz789")
        |> put_req_header("request-signature", "sig_test")
        |> UCPHeaders.call([])

      assert conn.assigns[:ucp_agent] == "test-agent/1.0"
      assert conn.assigns[:ucp_request_id] == "req_xyz789"
      assert conn.assigns[:ucp_signature] == "sig_test"
    end

    test "ignores empty headers" do
      conn =
        conn(:post, "/checkout-sessions")
        |> put_req_header("ucp-agent", "")
        |> UCPHeaders.call([])

      # Empty header should not be assigned
      # But request_id will be generated
      refute Map.has_key?(conn.assigns, :ucp_agent)
    end

    test "does not assign missing headers" do
      conn =
        conn(:post, "/checkout-sessions")
        |> UCPHeaders.call([])

      refute Map.has_key?(conn.assigns, :ucp_agent)
      refute Map.has_key?(conn.assigns, :ucp_signature)
      # request_id should be generated
      assert Map.has_key?(conn.assigns, :ucp_request_id)
    end
  end

  describe "call/2 request ID generation" do
    test "generates request ID when not provided" do
      conn =
        conn(:post, "/checkout-sessions")
        |> UCPHeaders.call([])

      assert conn.assigns[:ucp_request_id] != nil
      assert String.starts_with?(conn.assigns[:ucp_request_id], "req_")
    end

    test "uses provided request ID instead of generating" do
      conn =
        conn(:post, "/checkout-sessions")
        |> put_req_header("ucp-request-id", "custom_req_123")
        |> UCPHeaders.call([])

      assert conn.assigns[:ucp_request_id] == "custom_req_123"
    end

    test "sets request ID in response header when generated" do
      conn =
        conn(:post, "/checkout-sessions")
        |> UCPHeaders.call([])

      request_id = conn.assigns[:ucp_request_id]
      assert get_resp_header(conn, "ucp-request-id") == [request_id]
    end

    test "echoes request ID in response header when provided" do
      conn =
        conn(:post, "/checkout-sessions")
        |> put_req_header("ucp-request-id", "provided_req_456")
        |> UCPHeaders.call([])

      assert get_resp_header(conn, "ucp-request-id") == ["provided_req_456"]
    end

    test "generated request IDs are unique" do
      conn1 =
        conn(:post, "/checkout-sessions")
        |> UCPHeaders.call([])

      conn2 =
        conn(:post, "/checkout-sessions")
        |> UCPHeaders.call([])

      refute conn1.assigns[:ucp_request_id] == conn2.assigns[:ucp_request_id]
    end

    test "generated request IDs have consistent format" do
      conn =
        conn(:post, "/checkout-sessions")
        |> UCPHeaders.call([])

      request_id = conn.assigns[:ucp_request_id]

      # Should start with "req_"
      assert String.starts_with?(request_id, "req_")

      # Should be base32 encoded (lowercase, no padding)
      suffix = String.replace_prefix(request_id, "req_", "")
      assert String.match?(suffix, ~r/^[a-z2-7]+$/)
    end
  end

  describe "plug behavior" do
    test "does not halt connection" do
      conn =
        conn(:post, "/checkout-sessions")
        |> UCPHeaders.call([])

      refute conn.halted
    end

    test "passes through all requests" do
      conn =
        conn(:get, "/orders/123")
        |> UCPHeaders.call([])

      refute conn.halted
      assert conn.assigns[:ucp_request_id] != nil
    end
  end

  describe "UCP-Agent parsing and version negotiation" do
    test "assigns the profile URL and version from the header" do
      conn =
        conn(:get, "/")
        |> put_req_header(
          "ucp-agent",
          ~s(profile="https://p.example/.well-known/ucp"; version="#{Bazaar.DiscoveryProfile.version()}")
        )
        |> UCPHeaders.call(UCPHeaders.init([]))

      refute conn.halted
      assert conn.assigns.ucp_agent_profile == "https://p.example/.well-known/ucp"
      assert conn.assigns.ucp_agent_version == Bazaar.DiscoveryProfile.version()
    end

    test "rejects a version this server does not speak" do
      conn =
        conn(:get, "/")
        |> put_req_header(
          "ucp-agent",
          ~s(profile="https://p.example/profile.json"; version="2099-01-01")
        )
        |> UCPHeaders.call(UCPHeaders.init([]))

      assert conn.halted
      assert conn.status == 422
      assert [%{"code" => "unsupported_version"}] = JSON.decode!(conn.resp_body)["messages"]
    end

    test "passes without a version parameter and when negotiation is off" do
      conn =
        conn(:get, "/")
        |> put_req_header("ucp-agent", ~s(profile="https://p.example/profile.json"))
        |> UCPHeaders.call(UCPHeaders.init([]))

      refute conn.halted
      assert conn.assigns.ucp_agent_version == nil

      conn =
        conn(:get, "/")
        |> put_req_header("ucp-agent", ~s(version="2099-01-01"))
        |> UCPHeaders.call(UCPHeaders.init(version: false))

      refute conn.halted
    end
  end
end
