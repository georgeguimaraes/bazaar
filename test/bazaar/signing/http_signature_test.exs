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

      assert :ok = HttpSignature.verify(signed, public)
      assert {:error, :digest_mismatch} = HttpSignature.verify(%{signed | body: "{}"}, public)

      tampered_headers = List.keyreplace(signed.headers, "webhook-id", 0, {"webhook-id", "wh_2"})

      assert {:error, :invalid_signature} =
               HttpSignature.verify(%{signed | headers: tampered_headers}, public)

      assert {:error, :missing_signature_input} = HttpSignature.verify(request(), public)
    end
  end
end
