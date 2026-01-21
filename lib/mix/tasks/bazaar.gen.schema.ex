defmodule Mix.Tasks.Bazaar.Gen.Schema do
  @shortdoc "Generates Elixir schema from UCP JSON Schema"

  @moduledoc """
  Generates Elixir schema modules from UCP JSON Schema files.

      $ mix bazaar.gen.schema priv/ucp_schemas/2026-01-11/shopping/types/buyer.json

  This will output Elixir code that can be copied into your schema modules.

  ## Options

    * `--module` - Module name for the generated schema (optional)
    * `--output` - Output file path (optional, defaults to stdout)

  ## Examples

      # Generate to stdout
      $ mix bazaar.gen.schema priv/ucp_schemas/2026-01-11/shopping/types/total_resp.json

      # Generate with module name
      $ mix bazaar.gen.schema priv/ucp_schemas/2026-01-11/shopping/types/buyer.json --module Bazaar.Schemas.Buyer

      # Generate to file
      $ mix bazaar.gen.schema priv/ucp_schemas/2026-01-11/shopping/checkout_resp.json --output lib/bazaar/schemas/shopping/checkout.ex
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, args, _} =
      OptionParser.parse(args,
        strict: [module: :string, output: :string, prefix: :string],
        aliases: [m: :module, o: :output, p: :prefix]
      )

    case args do
      [schema_path] ->
        generate(schema_path, opts)

      [] ->
        Mix.shell().error(
          "Usage: mix bazaar.gen.schema <schema_path> [--module Module] [--prefix Prefix] [--output path]"
        )

        exit({:shutdown, 1})

      _ ->
        Mix.shell().error("Expected exactly one schema path")
        exit({:shutdown, 1})
    end
  end

  @default_module_prefix "Bazaar.Schemas"

  defp generate(schema_path, opts) do
    module_prefix = opts[:prefix] || @default_module_prefix

    schemax_opts = [
      module: opts[:module] || infer_module_name(schema_path, module_prefix),
      module_prefix: module_prefix,
      schemas_dir: find_schemas_dir(schema_path),
      format: :ecto_schema
    ]

    case Smelter.compile(schema_path, schemax_opts) do
      {:ok, output} ->
        case opts[:output] do
          nil ->
            Mix.shell().info(output)

          output_path ->
            File.mkdir_p!(Path.dirname(output_path))
            File.write!(output_path, output)
            Mix.shell().info("Generated #{output_path}")
        end

      {:error, reason} ->
        Mix.shell().error("Failed to generate schema: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  # For backwards compatibility - exposed for batch generator
  @doc false
  def generate_code(schema, schema_path, opts) do
    module_prefix = opts[:module_prefix] || @default_module_prefix

    schemax_opts = [
      module: opts[:module] || infer_module_name(schema_path, module_prefix),
      module_prefix: module_prefix,
      schemas_dir: find_schemas_dir(schema_path),
      format: :ecto_schema
    ]

    schema_with_path = Map.put(schema, :_source_path, schema_path)

    {:ok, resolved} = Smelter.Resolver.resolve(schema_with_path, schema_path, schemax_opts)
    Smelter.Generator.generate(resolved, schemax_opts)
  end

  defp find_schemas_dir(schema_path) do
    case Regex.run(~r|^(.+/ucp_schemas)|, Path.expand(schema_path)) do
      [_, dir] -> dir
      nil -> Path.dirname(schema_path)
    end
  end

  defp find_schemas_base(path) do
    case Regex.run(~r|ucp_schemas/[\d-]+/(.+)$|, path) do
      [_, relative] -> {:ok, relative}
      nil -> :error
    end
  end

  defp infer_module_name(schema_path, module_prefix) do
    case find_schemas_base(Path.expand(schema_path)) do
      {:ok, relative_path} ->
        parts =
          relative_path
          |> Path.rootname(".json")
          |> String.split("/")
          |> Enum.map_join(".", &camelize_part/1)

        "#{module_prefix}.#{parts}"

      :error ->
        base = camelize_part(Path.basename(schema_path, ".json"))
        "#{module_prefix}.#{base}"
    end
  end

  defp camelize_part(part) do
    part
    |> String.replace(~r/[._]/, " ")
    |> String.split()
    |> Enum.map_join(&String.capitalize/1)
  end
end
