defmodule Mix.Tasks.Bazaar.Gen.Schemas do
  @shortdoc "Generates all Elixir schemas from JSON Schema directory"

  @moduledoc """
  Generates Elixir schema modules for all JSON Schema files in a directory.

      $ mix bazaar.gen.schemas priv/ucp_schemas/2026-01-11

  This will generate Elixir modules for all `.json` schema files found
  in the directory (recursively) and output them to `lib/bazaar/schemas/`.

  ## Options

    * `--output-dir` - Output directory (default: lib/bazaar/schemas)
    * `--prefix` - Module prefix (default: Bazaar.Schemas)
    * `--dry-run` - Show what would be generated without writing files

  ## Examples

      # Generate all schemas
      $ mix bazaar.gen.schemas priv/ucp_schemas/2026-01-11

      # Generate to custom directory
      $ mix bazaar.gen.schemas priv/ucp_schemas/2026-01-11 --output-dir lib/generated

      # Generate with custom prefix (for ACP schemas)
      $ mix bazaar.gen.schemas priv/acp_schemas --prefix Bazaar.Schemas.Acp --output-dir lib/bazaar/schemas/acp

      # Preview what would be generated
      $ mix bazaar.gen.schemas priv/ucp_schemas/2026-01-11 --dry-run
  """

  use Mix.Task

  @default_output_dir "lib/bazaar/schemas"
  @default_module_prefix "Bazaar.Schemas"

  @impl Mix.Task
  def run(args) do
    {opts, args, _} =
      OptionParser.parse(args,
        strict: [output_dir: :string, prefix: :string, dry_run: :boolean],
        aliases: [o: :output_dir, p: :prefix, n: :dry_run]
      )

    case args do
      [schema_dir] ->
        generate_all(schema_dir, opts)

      [] ->
        Mix.shell().error(
          "Usage: mix bazaar.gen.schemas <schema_dir> [--output-dir path] [--prefix Module] [--dry-run]"
        )

        exit({:shutdown, 1})

      _ ->
        Mix.shell().error("Expected exactly one schema directory")
        exit({:shutdown, 1})
    end
  end

  defp generate_all(schema_dir, opts) do
    output_dir = opts[:output_dir] || @default_output_dir
    module_prefix = opts[:prefix] || @default_module_prefix
    dry_run = opts[:dry_run] || false

    schema_files =
      Path.wildcard(Path.join(schema_dir, "**/*.json"))
      |> Enum.reject(&String.contains?(&1, "node_modules"))
      |> Enum.sort()

    if schema_files == [] do
      Mix.shell().error("No JSON schema files found in #{schema_dir}")
      exit({:shutdown, 1})
    end

    Mix.shell().info("Found #{length(schema_files)} schema files")

    unless dry_run do
      File.rm_rf!(output_dir)
      File.mkdir_p!(output_dir)
    end

    results =
      Enum.map(schema_files, fn schema_path ->
        generate_one(schema_path, schema_dir, output_dir, module_prefix, dry_run)
      end)

    successful = Enum.count(results, &match?({:ok, _}, &1))
    failed = Enum.count(results, &match?({:error, _}, &1))

    Mix.shell().info("")

    Mix.shell().info(
      "Generated #{successful} schemas#{if failed > 0, do: ", #{failed} failed", else: ""}"
    )

    if dry_run do
      Mix.shell().info("(dry run - no files written)")
    end
  end

  defp generate_one(schema_path, schema_dir, output_dir, module_prefix, dry_run) do
    relative_path = Path.relative_to(schema_path, schema_dir)
    output_path = schema_to_elixir_path(relative_path, output_dir)
    module_name = infer_module_name(relative_path, module_prefix)

    case File.read(schema_path) do
      {:ok, content} ->
        case JSON.decode(content) do
          {:ok, schema} ->
            results = []

            # Generate module for the main schema if it's generatable
            # Check if main schema is generatable (has properties or composition)
            # Files with only $defs are processed below for their definitions
            results =
              if generatable?(schema) do
                result =
                  generate_schema_module(
                    schema,
                    schema_path,
                    module_name,
                    module_prefix,
                    output_path,
                    relative_path,
                    dry_run
                  )

                [result | results]
              else
                defs = schema["$defs"] || %{}
                generatable_defs = Enum.count(defs, fn {_, d} -> generatable?(d) end)

                if generatable_defs > 0 do
                  Mix.shell().info(
                    "  Skipped #{relative_path} root (container only, #{generatable_defs} $defs processed below)"
                  )
                else
                  Mix.shell().info("  Skipped #{relative_path} (no properties or composition)")
                end

                [{:ok, :skipped} | results]
              end

            # Generate modules for $defs entries
            defs_results =
              generate_defs(
                schema,
                schema_path,
                schema_dir,
                output_dir,
                module_prefix,
                relative_path,
                dry_run
              )

            results ++ defs_results

          {:error, error} ->
            Mix.shell().error("  Failed to parse #{relative_path}: #{inspect(error)}")
            {:error, error}
        end

      {:error, reason} ->
        Mix.shell().error("  Failed to read #{relative_path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp generate_schema_module(
         schema,
         schema_path,
         module_name,
         module_prefix,
         output_path,
         relative_path,
         dry_run
       ) do
    code =
      Mix.Tasks.Bazaar.Gen.Schema.generate_code(schema, schema_path,
        module: module_name,
        module_prefix: module_prefix
      )

    if dry_run do
      Mix.shell().info("  #{relative_path} -> #{output_path}")
    else
      File.mkdir_p!(Path.dirname(output_path))
      File.write!(output_path, code)
      Mix.shell().info("  Generated #{output_path}")
    end

    {:ok, output_path}
  end

  defp generate_defs(
         schema,
         schema_path,
         _schema_dir,
         output_dir,
         module_prefix,
         relative_path,
         dry_run
       ) do
    defs = schema["$defs"] || %{}

    Enum.flat_map(defs, fn {def_name, def_schema} ->
      if generatable?(def_schema) do
        # Build paths for this $def
        base_name = Path.rootname(relative_path, ".json")
        def_file_name = Macro.underscore(def_name)
        def_output_path = Path.join([output_dir, base_name, "#{def_file_name}.ex"])
        def_module_name = infer_def_module_name(relative_path, def_name, module_prefix)
        def_relative = "#{relative_path}#/$defs/#{def_name}"

        result =
          generate_def_module(
            def_schema,
            schema,
            schema_path,
            def_module_name,
            module_prefix,
            def_output_path,
            def_relative,
            dry_run
          )

        [result]
      else
        []
      end
    end)
  end

  # Generate module for a $def entry, passing root schema for local ref resolution
  defp generate_def_module(
         def_schema,
         root_schema,
         schema_path,
         module_name,
         module_prefix,
         output_path,
         relative_path,
         dry_run
       ) do
    # Resolve the def schema with access to root schema's $defs for local refs
    {:ok, resolved} =
      Smelter.Resolver.resolve(
        def_schema,
        schema_path,
        module_prefix: module_prefix,
        root_schema: root_schema
      )

    code = Smelter.Generator.generate(resolved, module: module_name, format: :ecto_schema)

    if dry_run do
      Mix.shell().info("  #{relative_path} -> #{output_path}")
    else
      File.mkdir_p!(Path.dirname(output_path))
      File.write!(output_path, code)
      Mix.shell().info("  Generated #{output_path}")
    end

    {:ok, output_path}
  end

  defp generatable?(schema) do
    Map.has_key?(schema, "properties") or
      Map.has_key?(schema, "oneOf") or
      Map.has_key?(schema, "anyOf") or
      Map.has_key?(schema, "allOf")
  end

  defp schema_to_elixir_path(relative_path, output_dir) do
    relative_path
    |> String.replace(".json", "")
    |> String.replace(~r/[.]/, "_")
    |> Kernel.<>(".ex")
    |> then(&Path.join(output_dir, &1))
  end

  defp infer_module_name(relative_path, module_prefix) do
    parts =
      relative_path
      |> Path.rootname(".json")
      |> String.split("/")
      |> Enum.map_join(".", &camelize_part/1)

    "#{module_prefix}.#{parts}"
  end

  defp infer_def_module_name(relative_path, def_name, module_prefix) do
    base_module = infer_module_name(relative_path, module_prefix)
    def_part = camelize_part(def_name)
    "#{base_module}.#{def_part}"
  end

  defp camelize_part(part) do
    part
    |> String.replace(~r/[._]/, " ")
    |> String.split()
    |> Enum.map_join(&String.capitalize/1)
  end
end
