defmodule Bazaar.Signing.HttpSignature do
  @moduledoc """
  HTTP message signatures (RFC 9421) the way UCP uses them.

  `sign/3` adds `Content-Digest`, `Signature-Input` and `Signature` headers to
  a request. The signature base covers `@method`, `@authority`, `@path`,
  `@query` when present, `content-digest`, `content-type` and any extra
  headers named in `:components`, in that order, followed by the
  `@signature-params` line with `created` and `keyid`. No `alg` parameter: the
  algorithm follows from the key's type, as the spec requires.

  A request is `%{method: "POST", url: "https://...", headers: [{name, value}], body: binary}`
  with lowercase header names.
  """

  alias Bazaar.Signing.Key

  @label "sig1"

  @doc """
  Signs a request. Returns the request's headers plus `content-digest`,
  `signature-input` and `signature`.

  ## Options

  - `:components` - extra header names to cover after `content-type`
  - `:created` - unix seconds for the `created` parameter, defaults to now
  """
  def sign(request, %Key{} = key, opts \\ []) do
    headers = request.headers ++ [{"content-digest", content_digest(request.body)}]
    request = %{request | headers: headers}

    components =
      ["@method", "@authority", "@path"] ++
        query_component(request.url) ++
        ["content-digest", "content-type"] ++ Keyword.get(opts, :components, [])

    created = Keyword.get(opts, :created, System.os_time(:second))
    params = params(components, created, key.kid)
    signature = Key.sign(key, signature_base(request, components, params))

    headers ++
      [
        {"signature-input", "#{@label}=#{params}"},
        {"signature", "#{@label}=:#{Base.encode64(signature)}:"}
      ]
  end

  @doc """
  Verifies a signed request against a public key. Checks the digest against
  the body and the signature against the reconstructed base.
  """
  def verify(request, %Key{} = key) do
    with {:ok, params, components} <-
           parse_signature_input(header(request.headers, "signature-input")),
         {:ok, signature} <- parse_signature(header(request.headers, "signature")),
         :ok <- check_digest(request) do
      if Key.verify(key, signature_base(request, components, params), signature) do
        :ok
      else
        {:error, :invalid_signature}
      end
    end
  end

  @doc "The `Content-Digest` value for a body."
  def content_digest(body), do: "sha-256=:#{Base.encode64(:crypto.hash(:sha256, body))}:"

  @doc "The signature base for a request, one covered component per line."
  def signature_base(request, components, params) do
    lines =
      Enum.map(components, fn component ->
        ~s("#{component}": #{component_value(request, component)})
      end)

    Enum.join(lines ++ [~s("@signature-params": #{params})], "\n")
  end

  defp params(components, created, kid) do
    list = Enum.map_join(components, " ", &~s("#{&1}"))
    ~s[(#{list});created=#{created};keyid="#{kid}"]
  end

  defp query_component(url) do
    case URI.parse(url).query do
      nil -> []
      _query -> ["@query"]
    end
  end

  defp component_value(request, "@method"), do: String.upcase(request.method)
  defp component_value(request, "@authority"), do: authority(URI.parse(request.url))
  defp component_value(request, "@path"), do: URI.parse(request.url).path || "/"
  defp component_value(request, "@query"), do: "?" <> (URI.parse(request.url).query || "")

  defp component_value(request, name) do
    request.headers
    |> Enum.filter(fn {key, _} -> key == name end)
    |> Enum.map_join(", ", fn {_, value} -> String.trim(value) end)
  end

  defp authority(%URI{host: host, port: port, scheme: scheme}) do
    host = String.downcase(host || "")
    if port == URI.default_port(scheme || ""), do: host, else: "#{host}:#{port}"
  end

  defp header(headers, name) do
    Enum.find_value(headers, fn {key, value} -> key == name && value end)
  end

  defp parse_signature_input(nil), do: {:error, :missing_signature_input}

  defp parse_signature_input(value) do
    case Regex.run(~r/^#{@label}=(\((.*?)\).*)$/, value) do
      [_, params, list] ->
        components = list |> String.split(" ", trim: true) |> Enum.map(&String.trim(&1, ~s(")))
        {:ok, params, components}

      nil ->
        {:error, :malformed_signature_input}
    end
  end

  defp parse_signature(nil), do: {:error, :missing_signature}

  defp parse_signature(value) do
    with [_, encoded] <- Regex.run(~r/^#{@label}=:([A-Za-z0-9+\/=]+):$/, value),
         {:ok, signature} <- Base.decode64(encoded) do
      {:ok, signature}
    else
      _ -> {:error, :malformed_signature}
    end
  end

  defp check_digest(request) do
    if header(request.headers, "content-digest") == content_digest(request.body) do
      :ok
    else
      {:error, :digest_mismatch}
    end
  end
end
