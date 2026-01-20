defmodule Bazaar.Webhook.SignatureTest do
  use ExUnit.Case, async: true

  alias Bazaar.Webhook.Signature

  @secret "test_webhook_secret_key_12345"
  @payload %{
    "event_id" => "evt_123",
    "event_type" => "order_created",
    "order" => %{"id" => "ord_1"}
  }

  describe "sign/2" do
    test "returns a JWT detached signature" do
      signature = Signature.sign(@payload, @secret)

      # Detached JWT has format: header..signature (no payload)
      assert is_binary(signature)
      parts = String.split(signature, ".")
      assert length(parts) == 3
      # Middle part (payload) should be empty for detached
      assert Enum.at(parts, 1) == ""
    end

    test "header specifies HS256 algorithm" do
      signature = Signature.sign(@payload, @secret)
      [header_b64 | _] = String.split(signature, ".")

      {:ok, header_json} = Base.url_decode64(header_b64, padding: false)
      header = JSON.decode!(header_json)

      assert header["alg"] == "HS256"
      assert header["typ"] == "JWT"
    end

    test "same payload and secret produce same signature" do
      sig1 = Signature.sign(@payload, @secret)
      sig2 = Signature.sign(@payload, @secret)

      assert sig1 == sig2
    end

    test "different payloads produce different signatures" do
      sig1 = Signature.sign(@payload, @secret)
      sig2 = Signature.sign(%{"different" => "payload"}, @secret)

      refute sig1 == sig2
    end

    test "different secrets produce different signatures" do
      sig1 = Signature.sign(@payload, @secret)
      sig2 = Signature.sign(@payload, "different_secret")

      refute sig1 == sig2
    end
  end

  describe "verify/3" do
    test "returns :ok for valid signature" do
      signature = Signature.sign(@payload, @secret)

      assert Signature.verify(signature, @payload, @secret) == :ok
    end

    test "returns error for tampered payload" do
      signature = Signature.sign(@payload, @secret)
      tampered = Map.put(@payload, "event_id", "evt_tampered")

      assert {:error, :invalid_signature} = Signature.verify(signature, tampered, @secret)
    end

    test "returns error for wrong secret" do
      signature = Signature.sign(@payload, @secret)

      assert {:error, :invalid_signature} = Signature.verify(signature, @payload, "wrong_secret")
    end

    test "returns error for malformed signature" do
      assert {:error, :malformed_signature} =
               Signature.verify("not.a.valid.jwt", @payload, @secret)

      assert {:error, :malformed_signature} = Signature.verify("invalid", @payload, @secret)
      assert {:error, :malformed_signature} = Signature.verify("", @payload, @secret)
    end

    test "returns error for non-detached signature" do
      # A full JWT with payload would have content in the middle
      full_jwt =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"

      assert {:error, :not_detached} = Signature.verify(full_jwt, @payload, @secret)
    end
  end

  describe "header/0" do
    test "returns the request-signature header name" do
      assert Signature.header() == "request-signature"
    end
  end
end
