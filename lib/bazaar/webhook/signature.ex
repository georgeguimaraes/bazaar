defmodule Bazaar.Webhook.Signature do
  @moduledoc """
  JWT signature generation and verification for webhooks.

  Uses RFC 7797 detached payload signatures with HS256 algorithm.
  The signature proves the webhook payload came from an authorized sender
  without including the payload in the JWT itself.

  ## Detached Signature Format

  A standard JWT has format: `header.payload.signature`
  A detached JWT has format: `header..signature` (empty payload section)

  The signature is still computed over `header.payload`, but only
  `header..signature` is transmitted. The receiver must supply the
  payload to verify.

  ## Usage

      # Signing (sender)
      signature = Signature.sign(payload, secret)
      # Add to request header
      put_req_header(conn, Signature.header(), signature)

      # Verification (receiver)
      case Signature.verify(signature, payload, secret) do
        :ok -> process_webhook(payload)
        {:error, reason} -> reject_webhook(reason)
      end
  """

  @header_name "request-signature"

  @doc """
  Returns the HTTP header name for webhook signatures.
  """
  def header, do: @header_name

  @doc """
  Signs a payload and returns a detached JWT signature.

  The payload is JSON-encoded and used to compute the signature,
  but is not included in the resulting JWT (detached format).

  ## Parameters

  - `payload` - Map to sign (will be JSON-encoded)
  - `secret` - Signing secret (shared between sender and receiver)

  ## Returns

  A detached JWT string in format `header..signature`
  """
  def sign(payload, secret) when is_map(payload) and is_binary(secret) do
    header = encode_header()
    payload_b64 = encode_payload(payload)

    signing_input = header <> "." <> payload_b64
    signature = compute_signature(signing_input, secret)

    # Detached format: header..signature (empty payload section)
    header <> ".." <> signature
  end

  @doc """
  Verifies a detached JWT signature against a payload.

  ## Parameters

  - `signature` - Detached JWT string to verify
  - `payload` - Map that should have been signed
  - `secret` - Signing secret

  ## Returns

  - `:ok` if signature is valid
  - `{:error, :malformed_signature}` if JWT structure is invalid
  - `{:error, :not_detached}` if JWT has a payload (not detached)
  - `{:error, :invalid_signature}` if signature doesn't match
  """
  def verify(signature, payload, secret)
      when is_binary(signature) and is_map(payload) and is_binary(secret) do
    with {:ok, {header_b64, sig_b64}} <- parse_detached_jwt(signature) do
      verify_signature(header_b64, payload, sig_b64, secret)
    end
  end

  defp encode_header do
    %{"alg" => "HS256", "typ" => "JWT"}
    |> JSON.encode!()
    |> Base.url_encode64(padding: false)
  end

  defp encode_payload(payload) do
    payload
    |> JSON.encode!()
    |> Base.url_encode64(padding: false)
  end

  defp compute_signature(signing_input, secret) do
    :crypto.mac(:hmac, :sha256, secret, signing_input)
    |> Base.url_encode64(padding: false)
  end

  defp parse_detached_jwt(jwt) do
    case String.split(jwt, ".") do
      [header, "", signature] when header != "" and signature != "" ->
        {:ok, {header, signature}}

      [_header, payload, _signature] when payload != "" ->
        {:error, :not_detached}

      _ ->
        {:error, :malformed_signature}
    end
  end

  defp verify_signature(header_b64, payload, expected_sig, secret) do
    payload_b64 = encode_payload(payload)
    signing_input = header_b64 <> "." <> payload_b64
    computed_sig = compute_signature(signing_input, secret)

    if secure_compare(computed_sig, expected_sig) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  # Constant-time comparison to prevent timing attacks
  defp secure_compare(a, b) when byte_size(a) != byte_size(b), do: false

  defp secure_compare(a, b) do
    a_bytes = :binary.bin_to_list(a)
    b_bytes = :binary.bin_to_list(b)

    Enum.zip(a_bytes, b_bytes)
    |> Enum.reduce(0, fn {x, y}, acc -> Bitwise.bor(acc, Bitwise.bxor(x, y)) end)
    |> Kernel.==(0)
  end
end
