defmodule Bazaar.Signing.KeyTest do
  use ExUnit.Case, async: true

  alias Bazaar.Signing.Key

  describe "generate/1, from_jwk/1 and public_jwk/1" do
    for type <- [:p256, :ed25519] do
      test "#{type}: a private JWK round-trips and its public half verifies" do
        key = Key.generate(unquote(type))
        public = Key.public_jwk(key)

        private_jwk = Map.put(public, "d", Base.url_encode64(key.private, padding: false))
        reloaded = Key.from_jwk(private_jwk)
        assert reloaded.public == key.public
        assert reloaded.kid == key.kid

        signature = Key.sign(reloaded, "payload")
        assert byte_size(signature) == 64
        assert Key.verify(Key.from_jwk(public), "payload", signature)
        refute Key.verify(Key.from_jwk(public), "tampered", signature)
      end
    end

    test "the public JWK carries only public members and the thumbprint as kid" do
      key = Key.generate(:p256)
      jwk = Key.public_jwk(key)

      assert Map.keys(jwk) |> Enum.sort() == ~w(alg crv kid kty use x y)
      assert jwk["kid"] == Key.thumbprint(key)
      assert byte_size(Base.url_decode64!(jwk["x"], padding: false)) == 32
    end

    test "a public-only key refuses to sign" do
      key = Key.generate(:ed25519)
      public = Key.from_jwk(Key.public_jwk(key))

      assert_raise ArgumentError, ~r/public-only/, fn -> Key.sign(public, "x") end
    end

    test "rejects other key types" do
      assert_raise ArgumentError, ~r/unsupported JWK/, fn -> Key.from_jwk(%{"kty" => "RSA"}) end
    end
  end

  describe "thumbprint/1" do
    test "matches RFC 7638 computed over the sorted required members" do
      key = Key.generate(:p256)
      %{"x" => x, "y" => y} = Key.public_jwk(key)

      expected =
        :crypto.hash(:sha256, ~s({"crv":"P-256","kty":"EC","x":"#{x}","y":"#{y}"}))
        |> Base.url_encode64(padding: false)

      assert Key.thumbprint(key) == expected
    end
  end

  describe "from_pem/1" do
    test "loads an EC P-256 key and an Ed25519 key written by OpenSSL" do
      for {algorithm, kty} <- [{"ec -pkeyopt ec_paramgen_curve:P-256", "EC"}, {"ed25519", "OKP"}] do
        {pem, 0} =
          System.cmd("sh", ["-c", "openssl genpkey -algorithm #{algorithm} 2>/dev/null"])

        key = Key.from_pem(pem)
        assert key.kty == kty
        assert Key.verify(key, "msg", Key.sign(key, "msg"))
      end
    end
  end

  describe "ES256 signatures" do
    test "are 64 bytes even when r or s would need a DER padding byte" do
      key = Key.generate(:p256)

      # Enough signatures to hit high-bit r or s values with overwhelming probability.
      for i <- 1..32 do
        signature = Key.sign(key, "message #{i}")
        assert byte_size(signature) == 64
        assert Key.verify(key, "message #{i}", signature)
      end
    end
  end
end
