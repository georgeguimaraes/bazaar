if Code.ensure_loaded?(JSV) do
  defmodule Bazaar.Validator.Resolver do
    @moduledoc """
    Custom JSV resolver for loading UCP schemas from the priv directory.

    This resolver handles `$ref` references in UCP schemas by loading
    referenced schemas from the bundled schema files.
    """

    @behaviour JSV.Resolver

    @impl true
    def resolve(uri, opts) do
      schemas_dir = Keyword.fetch!(opts, :schemas_dir)

      # Handle different URI formats
      path = resolve_path(uri, schemas_dir)

      case File.read(path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, schema} -> {:ok, schema}
            {:error, reason} -> {:error, {:json_decode_error, reason}}
          end

        {:error, :enoent} ->
          {:error, {:schema_not_found, uri}}

        {:error, reason} ->
          {:error, {:file_read_error, reason}}
      end
    end

    defp resolve_path(uri, schemas_dir) when is_binary(uri) do
      # Handle relative paths like "types/buyer.json" or "../ucp.json"
      # Handle URIs like "https://ucp.dev/schemas/shopping/checkout.json"

      cond do
        # Absolute file path
        String.starts_with?(uri, "/") ->
          uri

        # UCP dev URIs - map to local files
        String.contains?(uri, "ucp.dev/schemas") ->
          uri
          |> String.replace(~r{https?://ucp\.dev/schemas/}, "")
          |> then(&Path.join(schemas_dir, &1))

        # Relative path with ../
        String.starts_with?(uri, "../") ->
          # Assuming we're in shopping/, go up one level
          uri
          |> String.replace_prefix("../", "")
          |> then(&Path.join(schemas_dir, &1))

        # Relative path to types/ or other subdirectories
        true ->
          Path.join([schemas_dir, "shopping", uri])
      end
    end

    defp resolve_path(%URI{} = uri, schemas_dir) do
      resolve_path(URI.to_string(uri), schemas_dir)
    end
  end
end
