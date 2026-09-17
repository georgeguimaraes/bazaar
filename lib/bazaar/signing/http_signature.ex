defmodule Bazaar.Signing.HttpSignature do
  @moduledoc """
  HTTP message signatures (RFC 9421) the way UCP uses them.

  `sign/3` adds `Content-Digest`, `Signature-Input` and `Signature` headers to
  a request. The signature base covers `@method`, `@authority`, `@path`,
  `@query` when present, `content-digest`, `content-type` and any extra
  components named in `:components`, in that order, followed by the
  `@signature-params` line with `created` and `keyid`. No `alg` parameter: the
  algorithm follows from the key's type, as the spec requires.

  `verify/2` checks a signed request against a public key, whatever label the
  signer used, and returns the signature parameters so the caller can apply
  its own freshness rules.

  A request is `%{method: "POST", url: "https://...", headers: [{name, value}], body: binary}`
  with lowercase header names. A component is a header name, a derived
  component such as `@path`, or a dictionary member such as
  `signature-agent;key="sig1"`.
  """

  alias Bazaar.Signing.Key

  @label "sig1"

  @doc """
  Signs a request. Returns the request's headers plus `content-digest`,
  `signature-input` and `signature`.

  ## Options

  - `:components` - extra components to cover after `content-type`
  - `:created` - unix seconds for the `created` parameter, defaults to now
  """
  def sign(request, %Key{} = key, opts \\ []) do
    # A request without a body carries no digest and covers no body headers.
    {headers, body_components} =
      if request.body in [nil, ""] do
        {request.headers, []}
      else
        {request.headers ++ [{"content-digest", content_digest(request.body)}],
         ["content-digest", "content-type"]}
      end

    request = %{request | headers: headers}

    components =
      ["@method", "@authority", "@path"] ++
        query_component(request.url) ++
        body_components ++ Keyword.get(opts, :components, [])

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

  Returns `{:ok, params}` with the signature's `keyid`, `created` and
  `expires` (integers or `nil`), or `{:error, reason}`.
  """
  def verify(request, %Key{} = key) do
    with {:ok, label, params, components} <-
           parse_signature_input(header(request.headers, "signature-input")),
         {:ok, signature} <- parse_signature(header(request.headers, "signature"), label),
         :ok <- check_digest(request) do
      if Key.verify(key, signature_base(request, components, params), signature) do
        {:ok, signature_params(params)}
      else
        {:error, :invalid_signature}
      end
    end
  end

  @doc "The `keyid` named by a request's `Signature-Input`, or `nil`."
  def keyid(headers) do
    case parse_signature_input(header(headers, "signature-input")) do
      {:ok, _label, params, _components} -> signature_params(params).keyid
      _ -> nil
    end
  end

  @doc "The `Content-Digest` value for a body."
  def content_digest(body), do: "sha-256=:#{Base.encode64(:crypto.hash(:sha256, body))}:"

  @doc "The signature base for a request, one covered component per line."
  def signature_base(request, components, params) do
    lines =
      Enum.map(components, fn component ->
        ~s(#{identifier(component)}: #{component_value(request, component)})
      end)

    Enum.join(lines ++ [~s("@signature-params": #{params})], "\n")
  end

  defp params(components, created, kid) do
    list = Enum.map_join(components, " ", &identifier/1)
    ~s[(#{list});created=#{created};keyid="#{kid}"]
  end

  # `name` becomes `"name"`, `name;key="k"` becomes `"name";key="k"`.
  defp identifier(component) do
    case String.split(component, ";", parts: 2) do
      [name] -> ~s("#{name}")
      [name, parameters] -> ~s("#{name}";#{parameters})
    end
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

  defp component_value(request, component) do
    case String.split(component, ";", parts: 2) do
      [name] ->
        header_value(request.headers, name)

      [name, parameters] ->
        case Regex.run(~r/key="([^"]+)"/, parameters) do
          [_, member] -> dictionary_member(header_value(request.headers, name), member)
          nil -> header_value(request.headers, name)
        end
    end
  end

  defp header_value(headers, name) do
    headers
    |> Enum.filter(fn {key, _} -> key == name end)
    |> Enum.map_join(", ", fn {_, value} -> String.trim(value) end)
  end

  # The value of one member of a structured-field dictionary header.
  defp dictionary_member(value, member) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.find_value("", fn entry ->
      case String.split(entry, "=", parts: 2) do
        [^member, member_value] -> member_value
        _ -> nil
      end
    end)
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
    case Regex.run(~r/^([A-Za-z0-9_-]+)=(\((.*?)\).*)$/, value) do
      [_, label, params, list] ->
        components =
          Regex.scan(~r/"([^"]+)"((?:;[a-z]+="[^"]*")*)/, list)
          |> Enum.map(fn [_, name, parameters] -> name <> parameters end)

        {:ok, label, params, components}

      nil ->
        {:error, :malformed_signature_input}
    end
  end

  defp parse_signature(nil, _label), do: {:error, :missing_signature}

  defp parse_signature(value, label) do
    with [_, encoded] <-
           Regex.run(~r/(?:^|,\s*)#{Regex.escape(label)}=:([A-Za-z0-9+\/=]+):/, value),
         {:ok, signature} <- Base.decode64(encoded) do
      {:ok, signature}
    else
      _ -> {:error, :malformed_signature}
    end
  end

  defp signature_params(params) do
    %{
      keyid: param(params, "keyid", &Function.identity/1),
      created: param(params, "created", &String.to_integer/1),
      expires: param(params, "expires", &String.to_integer/1)
    }
  end

  defp param(params, name, convert) do
    case Regex.run(~r/;#{name}=("?)([^;"]+)\1/, params) do
      [_, _, value] -> convert.(value)
      nil -> nil
    end
  end

  defp check_digest(request) do
    body = request.body || ""

    case header(request.headers, "content-digest") do
      nil when body == "" -> :ok
      digest -> if digest == content_digest(body), do: :ok, else: {:error, :digest_mismatch}
    end
  end
end
