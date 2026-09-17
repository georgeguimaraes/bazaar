defmodule Bazaar.UcpSchemasTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Structural checks over the bundled UCP schema tree, so a broken regeneration
  (missing variant, dangling ref) fails here instead of inside a validator call.
  """

  @schemas_dir :code.priv_dir(:bazaar) |> Path.join("ucp_schemas/2026-08-25")

  test "every file ref in the bundled tree points at a bundled file" do
    files = Path.wildcard(Path.join(@schemas_dir, "**/*.json"))
    assert files != []

    dangling =
      for file <- files,
          ref <- refs(JSON.decode!(File.read!(file))),
          target = target_path(ref, file),
          not File.exists?(target),
          do: {Path.relative_to(file, @schemas_dir), ref}

    assert dangling == []
  end

  test "the root schemas build through the resolver" do
    for schema <- [:checkout, :order, :profile] do
      # A built schema rejects the empty map on validation; a schema that failed
      # to build surfaces as a build error instead of a validation result.
      assert {:error, %{valid: false}} = Bazaar.Validator.validate(%{}, schema)
    end
  end

  defp refs(%{} = map) do
    Enum.flat_map(map, fn
      {"$ref", ref} when is_binary(ref) -> [ref]
      {_key, value} -> refs(value)
    end)
  end

  defp refs(list) when is_list(list), do: Enum.flat_map(list, &refs/1)
  defp refs(_), do: []

  # Mirrors how Bazaar.Validator.Resolver locates files: ucp.dev URLs and the
  # `../../schemas/` form used inside embedded transport blocks map to the
  # tree root, everything else is relative to the referencing file.
  defp target_path(ref, file) do
    path = ref |> String.split("#", parts: 2) |> hd()

    cond do
      path == "" ->
        file

      String.contains?(path, "schemas/") ->
        Path.join(@schemas_dir, List.last(String.split(path, "schemas/", parts: 2)))

      true ->
        Path.expand(path, Path.dirname(file))
    end
  end
end
