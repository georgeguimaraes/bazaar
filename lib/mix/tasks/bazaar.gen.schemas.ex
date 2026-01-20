defmodule Mix.Tasks.Bazaar.Gen.Schemas do
  @shortdoc "Generates all Schemecto schemas from UCP JSON Schema directory"

  @moduledoc """
  Generates Schemecto field definitions for all JSON Schema files in a directory.

      $ mix bazaar.gen.schemas priv/ucp_schemas/2026-01-11

  This will generate Elixir modules for all `.json` schema files found
  in the directory (recursively) and output them to `lib/bazaar/schemas/generated/`.

  ## Options

    * `--output-dir` - Output directory (default: lib/bazaar/schemas/generated)
    * `--dry-run` - Show what would be generated without writing files

  ## Examples

      # Generate all schemas
      $ mix bazaar.gen.schemas priv/ucp_schemas/2026-01-11

      # Generate to custom directory
      $ mix bazaar.gen.schemas priv/ucp_schemas/2026-01-11 --output-dir lib/generated

      # Preview what would be generated
      $ mix bazaar.gen.schemas priv/ucp_schemas/2026-01-11 --dry-run
  """

  use Mix.Task

  @default_output_dir "lib/bazaar/schemas/generated"

  @impl Mix.Task
  def run(args) do
    {opts, args, _} =
      OptionParser.parse(args,
        strict: [output_dir: :string, dry_run: :boolean],
        aliases: [o: :output_dir, n: :dry_run]
      )

    case args do
      [schema_dir] ->
        generate_all(schema_dir, opts)

      [] ->
        Mix.shell().error(
          "Usage: mix bazaar.gen.schemas <schema_dir> [--output-dir path] [--dry-run]"
        )

        exit({:shutdown, 1})

      _ ->
        Mix.shell().error("Expected exactly one schema directory")
        exit({:shutdown, 1})
    end
  end

  defp generate_all(schema_dir, opts) do
    output_dir = opts[:output_dir] || @default_output_dir
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
        generate_one(schema_path, schema_dir, output_dir, dry_run)
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

  defp generate_one(schema_path, schema_dir, output_dir, dry_run) do
    relative_path = Path.relative_to(schema_path, schema_dir)
    output_path = schema_to_elixir_path(relative_path, output_dir)
    module_name = infer_module_name(relative_path)

    case File.read(schema_path) do
      {:ok, content} ->
        case JSON.decode(content) do
          {:ok, schema} ->
            # Skip schemas without properties (like pure $defs schemas)
            if schema["properties"] do
              code =
                Mix.Tasks.Bazaar.Gen.Schema.generate_code(schema, schema_path,
                  module: module_name
                )

              if dry_run do
                Mix.shell().info("  #{relative_path} -> #{output_path}")
              else
                File.mkdir_p!(Path.dirname(output_path))
                File.write!(output_path, code)
                Mix.shell().info("  Generated #{output_path}")
              end

              {:ok, output_path}
            else
              Mix.shell().info("  Skipped #{relative_path} (no properties)")
              {:ok, :skipped}
            end

          {:error, error} ->
            Mix.shell().error("  Failed to parse #{relative_path}: #{inspect(error)}")
            {:error, error}
        end

      {:error, reason} ->
        Mix.shell().error("  Failed to read #{relative_path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp schema_to_elixir_path(relative_path, output_dir) do
    relative_path
    |> String.replace(".json", "")
    |> String.replace(~r/[.]/, "_")
    |> Kernel.<>(".ex")
    |> then(&Path.join(output_dir, &1))
  end

  defp infer_module_name(relative_path) do
    relative_path
    |> Path.rootname(".json")
    |> String.split("/")
    |> Enum.map(fn part ->
      part
      |> String.replace(~r/[._]/, " ")
      |> String.split()
      |> Enum.map(&String.capitalize/1)
      |> Enum.join()
    end)
    |> Enum.join(".")
    |> then(&"Bazaar.Schemas.Generated.#{&1}")
  end
end
