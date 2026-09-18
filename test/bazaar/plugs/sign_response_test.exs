defmodule Bazaar.Plugs.SignResponseTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias Bazaar.Plugs.SignResponse
  alias Bazaar.Signing.{HttpSignature, Key}

  @body ~s({"id":"chk_1","status":"completed"})

  defp respond(status, opts) do
    conn(:post, "/checkout-sessions/chk_1/complete")
    |> SignResponse.call(SignResponse.init(opts))
    |> put_resp_content_type("application/json")
    |> resp(status, @body)
    |> send_resp()
  end

  # The response as a platform receives it.
  defp received(conn) do
    %{
      status: conn.status,
      headers:
        Enum.filter(conn.resp_headers, fn {name, _} ->
          name in ~w(content-type content-digest signature-input signature)
        end),
      body: conn.resp_body
    }
  end

  test "signs 2xx responses so the published key verifies them, including the body" do
    key = Key.generate(:p256)
    conn = respond(200, key: fn -> key end)

    assert [_] = get_resp_header(conn, "signature")
    assert {:ok, %{keyid: keyid}} = HttpSignature.verify_response(received(conn), key)
    assert keyid == key.kid

    tampered = %{received(conn) | body: ~s({"id":"chk_1","status":"canceled"})}
    assert {:error, :digest_mismatch} = HttpSignature.verify_response(tampered, key)

    other = Key.generate(:ed25519)
    assert {:error, :invalid_signature} = HttpSignature.verify_response(received(conn), other)
  end

  test "leaves other statuses alone" do
    conn = respond(422, key: Key.generate(:ed25519))
    assert get_resp_header(conn, "signature") == []
    assert get_resp_header(conn, "content-digest") == []
  end

  test "covers status, digest and content type in the base" do
    key = Key.generate(:ed25519)

    headers =
      HttpSignature.sign_response(
        %{status: 201, headers: [{"content-type", "application/json"}], body: @body},
        key,
        created: 1
      )

    [input] = for {"signature-input", v} <- headers, do: v
    assert input =~ ~s[("@status" "content-digest" "content-type");created=1;keyid="#{key.kid}"]
  end
end
