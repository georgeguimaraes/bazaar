defmodule Bazaar.Signing.Key do
  @moduledoc """
  A signing key for UCP HTTP message signatures: EC P-256 (ES256) or
  Ed25519 (EdDSA), as the spec allows.

  Load one from a private JWK or PEM, or generate one for development:

      key = Bazaar.Signing.Key.from_pem(File.read!("webhook_key.pem"))
      key = Bazaar.Signing.Key.generate(:p256)

  Publish its public half in the discovery profile's `keys[]`:

      def business_profile, do: %{"keys" => [Bazaar.Signing.Key.public_jwk(key)]}

  The `kid` defaults to the RFC 7638 thumbprint, so a key republishes under
  a stable identifier wherever it is loaded.
  """

  @enforce_keys [:kty, :crv, :kid, :public]
  defstruct [:kty, :crv, :kid, :public, :private]

  @type t :: %__MODULE__{
          kty: String.t(),
          crv: String.t(),
          kid: String.t(),
          public: binary(),
          private: binary() | nil
        }

  @p256_oid {1, 2, 840, 10_045, 3, 1, 7}
  @ed25519_oid {1, 3, 101, 112}

  @doc "Generates a new key, `:p256` or `:ed25519`."
  def generate(:p256) do
    {public, private} = :crypto.generate_key(:ecdh, :secp256r1)
    build("EC", "P-256", public, private, nil)
  end

  def generate(:ed25519) do
    {public, private} = :crypto.generate_key(:eddsa, :ed25519)
    build("OKP", "Ed25519", public, private, nil)
  end

  @doc """
  Loads a key from a JWK map. A private key carries `d`; without it the key
  can only verify.
  """
  def from_jwk(%{"kty" => "EC", "crv" => "P-256"} = jwk) do
    private = jwk["d"] && decode(jwk["d"])

    public =
      case private do
        nil -> <<4>> <> pad(decode(jwk["x"])) <> pad(decode(jwk["y"]))
        d -> elem(:crypto.generate_key(:ecdh, :secp256r1, d), 0)
      end

    build("EC", "P-256", public, private, jwk["kid"])
  end

  def from_jwk(%{"kty" => "OKP", "crv" => "Ed25519"} = jwk) do
    private = jwk["d"] && decode(jwk["d"])

    public =
      case private do
        nil -> decode(jwk["x"])
        d -> elem(:crypto.generate_key(:eddsa, :ed25519, d), 0)
      end

    build("OKP", "Ed25519", public, private, jwk["kid"])
  end

  def from_jwk(jwk) do
    raise ArgumentError, "unsupported JWK, expected EC P-256 or OKP Ed25519, got: #{inspect(jwk)}"
  end

  @doc "Loads a private key from PEM (EC P-256 or Ed25519, SEC 1 or PKCS#8)."
  def from_pem(pem) when is_binary(pem) do
    case :public_key.pem_decode(pem) do
      [entry | _] -> from_private_key_record(:public_key.pem_entry_decode(entry))
      [] -> raise ArgumentError, "no PEM entry found"
    end
  end

  defp from_private_key_record(record) when elem(record, 0) == :ECPrivateKey do
    private = elem(record, 2)

    case elem(record, 3) do
      {:namedCurve, @p256_oid} ->
        build(
          "EC",
          "P-256",
          elem(:crypto.generate_key(:ecdh, :secp256r1, private), 0),
          private,
          nil
        )

      {:namedCurve, @ed25519_oid} ->
        build(
          "OKP",
          "Ed25519",
          elem(:crypto.generate_key(:eddsa, :ed25519, private), 0),
          private,
          nil
        )

      other ->
        raise ArgumentError, "unsupported curve #{inspect(other)}, expected P-256 or Ed25519"
    end
  end

  defp from_private_key_record(other) do
    raise ArgumentError,
          "unsupported PEM key #{inspect(elem(other, 0))}, expected an EC or Ed25519 private key"
  end

  @doc "The public JWK to publish in a profile's `keys[]`."
  def public_jwk(%__MODULE__{kty: "EC", public: <<4, x::binary-32, y::binary-32>>} = key) do
    %{
      "kty" => "EC",
      "crv" => "P-256",
      "x" => encode(x),
      "y" => encode(y),
      "kid" => key.kid,
      "use" => "sig",
      "alg" => "ES256"
    }
  end

  def public_jwk(%__MODULE__{kty: "OKP", public: x} = key) do
    %{
      "kty" => "OKP",
      "crv" => "Ed25519",
      "x" => encode(x),
      "kid" => key.kid,
      "use" => "sig",
      "alg" => "EdDSA"
    }
  end

  @doc "RFC 7638 thumbprint: required public members, sorted, hashed with SHA-256."
  def thumbprint(%__MODULE__{kty: "EC", public: <<4, x::binary-32, y::binary-32>>}) do
    digest(~s({"crv":"P-256","kty":"EC","x":"#{encode(x)}","y":"#{encode(y)}"}))
  end

  def thumbprint(%__MODULE__{kty: "OKP", public: x}) do
    digest(~s({"crv":"Ed25519","kty":"OKP","x":"#{encode(x)}"}))
  end

  @doc "Signs bytes. ES256 signatures are the fixed-width `r || s` form, not DER."
  def sign(%__MODULE__{private: nil}, _message) do
    raise ArgumentError, "cannot sign with a public-only key"
  end

  def sign(%__MODULE__{kty: "EC", private: d}, message) do
    :ecdsa |> :crypto.sign(:sha256, message, [d, :secp256r1]) |> der_to_raw()
  end

  def sign(%__MODULE__{kty: "OKP", private: d}, message) do
    :crypto.sign(:eddsa, :none, message, [d, :ed25519])
  end

  @doc "Verifies a signature produced by `sign/2`."
  def verify(%__MODULE__{kty: "EC", public: public}, message, <<_::binary-64>> = signature) do
    :crypto.verify(:ecdsa, :sha256, message, raw_to_der(signature), [public, :secp256r1])
  end

  def verify(%__MODULE__{kty: "OKP", public: public}, message, <<_::binary-64>> = signature) do
    :crypto.verify(:eddsa, :none, message, signature, [public, :ed25519])
  end

  def verify(_key, _message, _signature), do: false

  defp build(kty, crv, public, private, kid) do
    key = %__MODULE__{kty: kty, crv: crv, kid: "pending", public: public, private: private}
    %{key | kid: kid || thumbprint(key)}
  end

  # DER ECDSA-Sig-Value <-> raw r || s (32 bytes each)

  defp der_to_raw(<<0x30, _len, 0x02, rl, r::binary-size(rl), 0x02, sl, s::binary-size(sl)>>) do
    pad(unpad(r)) <> pad(unpad(s))
  end

  defp raw_to_der(<<r::binary-32, s::binary-32>>) do
    r = der_integer(unpad(r))
    s = der_integer(unpad(s))
    <<0x30, byte_size(r) + byte_size(s)>> <> r <> s
  end

  defp der_integer(<<first, _::binary>> = bytes) when first >= 0x80,
    do: <<0x02, byte_size(bytes) + 1, 0>> <> bytes

  defp der_integer(bytes), do: <<0x02, byte_size(bytes)>> <> bytes

  defp unpad(<<0, rest::binary>>) when byte_size(rest) > 0, do: unpad(rest)
  defp unpad(bytes), do: bytes

  defp pad(bytes) when byte_size(bytes) >= 32, do: binary_part(bytes, byte_size(bytes) - 32, 32)
  defp pad(bytes), do: :binary.copy(<<0>>, 32 - byte_size(bytes)) <> bytes

  defp digest(json), do: :sha256 |> :crypto.hash(json) |> encode()
  defp encode(bytes), do: Base.url_encode64(bytes, padding: false)
  defp decode(text), do: Base.url_decode64!(text, padding: false)
end
