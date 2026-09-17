defmodule Bazaar.Signing.HttpSignatureTest do
  use ExUnit.Case, async: true

  alias Bazaar.Signing.{HttpSignature, Key}

  @body ~s({"id":"order_1"})

  defp request(url \\ "http://localhost:8284/webhooks/partners/test/events/order") do
    %{
      method: "post",
      url: url,
      headers: [{"content-type", "application/json"}, {"webhook-id", "wh_1"}],
      body: @body
    }
  end

  test "builds the signature base exactly as the spec lays it out" do
    key = Key.generate(:p256)

    headers =
      HttpSignature.sign(request(), key, components: ["webhook-id"], created: 1_738_617_600)

    digest = "sha-256=:#{Base.encode64(:crypto.hash(:sha256, @body))}:"

    assert {"content-digest", ^digest} = List.keyfind(headers, "content-digest", 0)

    params =
      ~s[("@method" "@authority" "@path" "content-digest" "content-type" "webhook-id");created=1738617600;keyid="#{key.kid}"]

    assert {"signature-input", "sig1=" <> ^params} = List.keyfind(headers, "signature-input", 0)

    base =
      HttpSignature.signature_base(
        %{request() | headers: headers},
        ~w(@method @authority @path content-digest content-type webhook-id),
        params
      )

    assert base ==
             Enum.join(
               [
                 ~s("@method": POST),
                 ~s("@authority": localhost:8284),
                 ~s("@path": /webhooks/partners/test/events/order),
                 ~s("content-digest": #{digest}),
                 ~s("content-type": application/json),
                 ~s("webhook-id": wh_1),
                 ~s("@signature-params": #{params})
               ],
               "\n"
             )
  end

  test "includes @query only when the URL has one and drops default ports" do
    key = Key.generate(:ed25519)
    headers = HttpSignature.sign(request("https://Platform.Example/hook?x=1"), key)
    {"signature-input", input} = List.keyfind(headers, "signature-input", 0)

    assert input =~ ~s("@path" "@query" "content-digest")

    assert HttpSignature.signature_base(
             %{request("https://Platform.Example/hook?x=1") | headers: headers},
             ["@authority", "@query"],
             ""
           ) =~
             ~s("@authority": platform.example\n"@query": ?x=1)
  end

  test "uses standard base64 in the digest and signature, never base64url" do
    key = Key.generate(:p256)
    headers = HttpSignature.sign(request(), key)
    {"signature", signature} = List.keyfind(headers, "signature", 0)

    assert signature =~ ~r/^sig1=:[A-Za-z0-9+\/=]+:$/
    refute List.keyfind(headers, "signature-input", 0) |> elem(1) =~ "alg="
  end

  for type <- [:p256, :ed25519] do
    test "#{type}: verifies with the public key and rejects tampering" do
      key = Key.generate(unquote(type))
      public = Key.from_jwk(Key.public_jwk(key))

      signed = %{
        request()
        | headers: HttpSignature.sign(request(), key, components: ["webhook-id"])
      }

      assert {:ok, _} = HttpSignature.verify(signed, public)
      assert {:error, :digest_mismatch} = HttpSignature.verify(%{signed | body: "{}"}, public)

      tampered_headers = List.keyreplace(signed.headers, "webhook-id", 0, {"webhook-id", "wh_2"})

      assert {:error, :invalid_signature} =
               HttpSignature.verify(%{signed | headers: tampered_headers}, public)

      assert {:error, :missing_signature_input} = HttpSignature.verify(request(), public)
    end
  end

  test "verifies any signature label and covers dictionary members like signature-agent" do
    key = Key.generate(:p256)
    public = Key.from_jwk(Key.public_jwk(key))

    request = %{
      request()
      | headers:
          request().headers ++ [{"signature-agent", ~s(sig1="https://p.example/.well-known/ucp")}]
    }

    headers =
      HttpSignature.sign(request, key,
        components: [~s(signature-agent;key="sig1")],
        created: 1_738_617_600
      )

    {"signature-input", input} = List.keyfind(headers, "signature-input", 0)
    assert input =~ ~s("signature-agent";key="sig1")

    relabeled =
      Enum.map(headers, fn
        {"signature-input", "sig1=" <> rest} -> {"signature-input", "wba=" <> rest}
        {"signature", "sig1=" <> rest} -> {"signature", "wba=" <> rest}
        other -> other
      end)

    assert {:ok, %{keyid: kid, created: 1_738_617_600, expires: nil}} =
             HttpSignature.verify(%{request | headers: relabeled}, public)

    assert kid == key.kid
    assert HttpSignature.keyid(relabeled) == key.kid
  end

  test "signs and verifies a request without a body, with no digest and no body components" do
    key = Key.generate(:p256)
    request = %{method: "GET", url: "https://shop.example/orders/1", headers: [], body: ""}
    headers = HttpSignature.sign(request, key)

    refute List.keyfind(headers, "content-digest", 0)
    {"signature-input", input} = List.keyfind(headers, "signature-input", 0)
    assert input =~ ~s[("@method" "@authority" "@path");created=]

    assert {:ok, _} =
             HttpSignature.verify(
               %{request | headers: headers},
               Key.from_jwk(Key.public_jwk(key))
             )
  end
end
