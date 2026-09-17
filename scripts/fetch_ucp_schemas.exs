# Fetches the UCP JSON Schemas for a spec version and writes the resolved,
# split variants that `mix bazaar.gen.schemas` and `Bazaar.Validator` consume.
#
#     mix run scripts/fetch_ucp_schemas.exs 2026-08-25
#     mix run scripts/fetch_ucp_schemas.exs 2026-08-25 --source ../ucp
#     mix run scripts/fetch_ucp_schemas.exs 2026-08-25 --output /tmp/ucp_schemas
#
# The UCP repo only ships annotated source schemas (`ucp_request` / `ucp_response`
# markers on fields). Up to v2026-01-23 the repo also committed a resolved `spec/`
# tree, which is what we copied into priv/ucp_schemas. That tree is gone, so this
# script rebuilds it: every annotated schema becomes `X_resp.json` plus
# `X.create_req.json`, `X.update_req.json` and `X.complete_req.json` (or a single
# `X_req.json` when the schema is marked `ucp_shared_request`), resolved with the
# official `ucp-schema` CLI. Schemas without annotations are copied as they are.
# Only `source/schemas/**` is read, and the output directory is replaced.
#
# `ucp-schema resolve` applies the annotations but leaves `$ref`, `$id` and
# `title` pointing at the base schema, so this script rewrites them the way the
# old docs build did: a `$ref` to an annotated schema points at the matching
# variant, request variants get their own `$id`, and titles get a
# "Response" / "Create Request" suffix.
#
# Requires Elixir 1.18+, git and the ucp-schema CLI (`cargo install ucp-schema`).

defmodule FetchUcpSchemas do
  @repo "https://github.com/Universal-Commerce-Protocol/ucp"
  @ops ["create", "update", "complete"]
  @annotation_keys ["ucp_request", "ucp_response", "ucp_shared_request"]

  def main(argv) do
    {opts, args, _} = OptionParser.parse(argv, strict: [source: :string, output: :string])

    version =
      case args do
        [v] ->
          v

        _ ->
          abort(
            "usage: mix run scripts/fetch_ucp_schemas.exs VERSION [--source DIR] [--output DIR]"
          )
      end

    unless System.find_executable("ucp-schema") do
      abort("ucp-schema not found. Install it with: cargo install ucp-schema")
    end

    output = opts[:output] || Path.join(["priv", "ucp_schemas", version])
    {source, cleanup} = source_checkout(opts[:source], version)

    try do
      schemas_root = Path.join([source, "source", "schemas"])
      File.dir?(schemas_root) || abort("no source/schemas directory under #{source}")

      files =
        schemas_root
        |> Path.join("**/*.json")
        |> Path.wildcard()
        |> Enum.map(&Path.relative_to(&1, schemas_root))
        |> Enum.sort()

      annotated =
        files
        |> Enum.filter(&annotated?(Path.join(schemas_root, &1)))
        |> MapSet.new()

      shared =
        annotated
        |> Enum.filter(&shared_request?(Path.join(schemas_root, &1)))
        |> MapSet.new()

      File.rm_rf!(output)
      File.mkdir_p!(output)

      {copied, generated} =
        Enum.reduce(files, {0, 0}, fn rel, {copied, generated} ->
          if MapSet.member?(annotated, rel) do
            n = generate_variants(rel, schemas_root, output, annotated, shared)
            {copied, generated + n}
          else
            copy(rel, schemas_root, output, annotated, shared)
            {copied + 1, generated}
          end
        end)

      IO.puts(
        "UCP #{version}: #{copied} copied, #{generated} generated from #{MapSet.size(annotated)} annotated schemas -> #{output}"
      )
    after
      cleanup.()
    end
  end

  defp source_checkout(nil, version) do
    dir =
      Path.join(System.tmp_dir!(), "bazaar-ucp-#{version}-#{System.unique_integer([:positive])}")

    IO.puts("Cloning #{@repo} at v#{version}...")

    case System.cmd(
           "git",
           ["clone", "--quiet", "--depth", "1", "--branch", "v#{version}", @repo, dir],
           stderr_to_stdout: true
         ) do
      {_, 0} -> {dir, fn -> File.rm_rf!(dir) end}
      {out, _} -> abort("git clone failed:\n#{out}")
    end
  end

  defp source_checkout(dir, _version), do: {Path.expand(dir), fn -> :ok end}

  # Unannotated schemas are copied as they are, except that refs to annotated
  # schemas must point at the response variant, since the base file is not
  # part of the output tree.
  defp copy(rel, root, output, annotated, shared) do
    schema =
      root
      |> Path.join(rel)
      |> File.read!()
      |> decode_ordered()
      |> rewrite_refs(rel, :response, "read", annotated, shared)

    write(Path.join(output, rel), schema)
  end

  defp generate_variants(rel, root, output, annotated, shared) do
    shared? = MapSet.member?(shared, rel)
    variants = [{:response, "read"} | request_variants(shared?)]

    Enum.each(variants, fn {direction, op} ->
      schema =
        rel
        |> resolve(root, direction, op)
        |> rewrite(rel, direction, op, annotated, shared)

      write(Path.join(output, variant_path(rel, direction, op, shared?)), schema)
    end)

    length(variants)
  end

  defp request_variants(true), do: [{:request, "create"}]
  defp request_variants(false), do: Enum.map(@ops, &{:request, &1})

  defp write(dest, schema) do
    File.mkdir_p!(Path.dirname(dest))
    File.write!(dest, encode(schema, "") <> "\n")
  end

  defp resolve(rel, root, direction, op) do
    flags = ["--#{direction}", "--op", op]

    case System.cmd("ucp-schema", ["resolve", Path.join(root, rel) | flags],
           stderr_to_stdout: true
         ) do
      {json, 0} -> decode_ordered(json)
      {out, _} -> abort("ucp-schema resolve #{rel} #{Enum.join(flags, " ")} failed:\n#{out}")
    end
  end

  # Variant file names, matching the tree the UCP repo used to commit under spec/.
  defp variant_path(rel, :response, _op, _shared), do: suffix(rel, "_resp")
  defp variant_path(rel, :request, _op, true), do: suffix(rel, "_req")
  defp variant_path(rel, :request, op, false), do: suffix(rel, ".#{op}_req")

  defp suffix(path, suffix), do: Path.rootname(path, ".json") <> suffix <> ".json"

  defp rewrite(schema, rel, direction, op, annotated, shared) do
    shared? = MapSet.member?(shared, rel)
    label = title_suffix(direction, op, shared?)
    {:obj, pairs} = rewrite_refs(schema, rel, direction, op, annotated, shared)

    pairs =
      pairs
      |> Enum.reject(fn {key, _} -> key == "ucp_shared_request" end)
      |> Enum.map(fn
        {"$id", id} when direction == :request and is_binary(id) ->
          {"$id", variant_path(id, direction, op, shared?)}

        {"title", title} ->
          {"title", suffix_title(title, label)}

        {"$defs", defs} ->
          {"$defs", suffix_titles(defs, label)}

        pair ->
          pair
      end)

    {:obj, pairs}
  end

  defp title_suffix(:response, _op, _shared), do: "Response"
  defp title_suffix(:request, _op, true), do: "Request"
  defp title_suffix(:request, op, false), do: "#{String.capitalize(op)} Request"

  defp suffix_title(title, label) when is_binary(title), do: "#{title} #{label}"
  defp suffix_title(title, _label), do: title

  # Every title under $defs gets the suffix, however deeply the defs nest.
  defp suffix_titles({:obj, pairs}, label) do
    {:obj,
     Enum.map(pairs, fn
       {"title", title} -> {"title", suffix_title(title, label)}
       {key, value} -> {key, suffix_titles(value, label)}
     end)}
  end

  defp suffix_titles(list, label) when is_list(list),
    do: Enum.map(list, &suffix_titles(&1, label))

  defp suffix_titles(other, _label), do: other

  defp rewrite_refs({:obj, pairs}, rel, direction, op, annotated, shared) do
    {:obj,
     Enum.map(pairs, fn
       {"$ref", ref} when is_binary(ref) ->
         {"$ref", rewrite_ref(ref, rel, direction, op, annotated, shared)}

       {key, value} ->
         {key, rewrite_refs(value, rel, direction, op, annotated, shared)}
     end)}
  end

  defp rewrite_refs(list, rel, direction, op, annotated, shared) when is_list(list) do
    Enum.map(list, &rewrite_refs(&1, rel, direction, op, annotated, shared))
  end

  defp rewrite_refs(other, _rel, _direction, _op, _annotated, _shared), do: other

  # Only refs to other schema files are rewritten. Fragments and absolute URLs
  # are left alone. Refs are resolved relative to the referencing file, except
  # the `../../schemas/...` form used inside embedded transport blocks, which is
  # relative to the docs site and is taken from its `schemas/` segment.
  defp rewrite_ref(ref, rel, direction, op, annotated, shared) do
    {path, fragment} =
      case String.split(ref, "#", parts: 2) do
        [path, fragment] -> {path, "#" <> fragment}
        [path] -> {path, ""}
      end

    if path == "" or String.starts_with?(path, "http") do
      ref
    else
      target =
        case String.split(path, "schemas/", parts: 2) do
          [_, after_schemas] -> after_schemas
          [_] -> Path.expand(path, Path.join("/", Path.dirname(rel))) |> String.trim_leading("/")
        end

      if MapSet.member?(annotated, target) do
        variant_path(path, direction, op, MapSet.member?(shared, target)) <> fragment
      else
        ref
      end
    end
  end

  defp annotated?(path), do: path |> File.read!() |> JSON.decode!() |> contains_annotation?()

  defp contains_annotation?(map) when is_map(map) do
    Enum.any?(map, fn {key, value} -> key in @annotation_keys or contains_annotation?(value) end)
  end

  defp contains_annotation?(list) when is_list(list), do: Enum.any?(list, &contains_annotation?/1)
  defp contains_annotation?(_), do: false

  defp shared_request?(path) do
    path |> File.read!() |> JSON.decode!() |> Map.get("ucp_shared_request") == true
  end

  # JSON objects are decoded as `{:obj, [{key, value}]}` so that key order is
  # preserved on the way out. The built-in JSON module has no pretty printer,
  # so the encoder below produces the same 2-space layout ucp-schema does.
  defp decode_ordered(json) do
    {schema, _acc, _rest} =
      JSON.decode(json, nil,
        object_finish: fn acc, old_acc -> {{:obj, Enum.reverse(acc)}, old_acc} end
      )

    schema
  end

  defp encode({:obj, []}, _indent), do: "{}"

  defp encode({:obj, pairs}, indent) do
    inner = indent <> "  "

    body =
      Enum.map_join(pairs, ",\n", fn {key, value} ->
        inner <> JSON.encode!(key) <> ": " <> encode(value, inner)
      end)

    "{\n" <> body <> "\n" <> indent <> "}"
  end

  defp encode([], _indent), do: "[]"

  defp encode(list, indent) when is_list(list) do
    inner = indent <> "  "
    body = Enum.map_join(list, ",\n", fn value -> inner <> encode(value, inner) end)
    "[\n" <> body <> "\n" <> indent <> "]"
  end

  defp encode(scalar, _indent), do: JSON.encode!(scalar)

  defp abort(message) do
    IO.puts(:stderr, message)
    System.halt(1)
  end
end

FetchUcpSchemas.main(System.argv())
