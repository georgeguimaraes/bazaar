defmodule Mix.Tasks.Bazaar.Gen.Schema do
  @shortdoc "Generates Schemecto field definitions from UCP JSON Schema"

  @moduledoc """
  Generates Schemecto field definitions from UCP JSON Schema files.

      $ mix bazaar.gen.schema priv/ucp_schemas/2026-01-11/shopping/types/buyer.json

  This will output Elixir code with Schemecto field definitions that can be
  copied into your schema modules.

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
        strict: [module: :string, output: :string],
        aliases: [m: :module, o: :output]
      )

    case args do
      [schema_path] ->
        generate(schema_path, opts)

      [] ->
        Mix.shell().error(
          "Usage: mix bazaar.gen.schema <schema_path> [--module Module] [--output path]"
        )

        exit({:shutdown, 1})

      _ ->
        Mix.shell().error("Expected exactly one schema path")
        exit({:shutdown, 1})
    end
  end

  defp generate(schema_path, opts) do
    schemax_opts = [
      module: opts[:module] || infer_module_name(schema_path),
      module_prefix: "Bazaar.Schemas",
      schemas_dir: find_schemas_dir(schema_path)
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
    schemax_opts = [
      module: opts[:module] || infer_module_name(schema_path),
      module_prefix: "Bazaar.Schemas",
      schemas_dir: find_schemas_dir(schema_path)
    ]

    schema_with_path = Map.put(schema, :_source_path, schema_path)

    case Smelter.Resolver.resolve(schema_with_path, schema_path, schemax_opts) do
      {:ok, resolved} ->
        Smelter.Generator.Schemecto.generate(resolved, schemax_opts)

      {:error, _reason} ->
        # Fallback to legacy generation if resolution fails
        legacy_generate_code(schema, schema_path, opts)
    end
  end

  # Legacy generation for compatibility
  defp legacy_generate_code(schema, schema_path, opts) do
    module_name = opts[:module] || infer_module_name(schema_path)
    title = schema["title"] || "Schema"
    description = schema["description"]
    properties = schema["properties"] || %{}
    required = schema["required"] || []

    fields = generate_fields(properties, schema_path)
    required_atoms = Enum.map(required, &String.to_atom/1)

    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      #{title}#{if description, do: "\n\n  #{description}", else: ""}

      Generated from: #{Path.basename(schema_path)}
      \"\"\"

      import Ecto.Changeset

    #{generate_enum_types(properties)}
      @fields [
    #{fields |> Enum.map(&"    #{&1}") |> Enum.join(",\n")}
      ]

      @doc "Returns the field definitions for this schema."
      def fields, do: @fields

      @doc "Creates a new changeset from params."
      def new(params \\\\ %{}) do
        Schemecto.new(@fields, params)
    #{generate_required_validation(required_atoms)}
      end
    end
    """
  end

  defp generate_fields(properties, schema_path) do
    properties
    |> Enum.sort_by(fn {name, _} -> name end)
    |> Enum.map(fn {name, prop} ->
      generate_field(name, prop, schema_path)
    end)
  end

  defp generate_field(name, prop, schema_path) do
    type = json_type_to_ecto(prop, name, schema_path)
    description = prop["description"]

    field_parts =
      [
        "name: :#{name}",
        "type: #{type}"
      ] ++
        if(description, do: ["description: #{inspect(description)}"], else: [])

    "%{#{Enum.join(field_parts, ", ")}}"
  end

  defp json_type_to_ecto(%{"$ref" => ref}, _name, schema_path) do
    ref_module = ref_to_module_name(ref, schema_path)
    "Schemecto.one(#{ref_module}.fields(), with: &Function.identity/1)"
  end

  defp json_type_to_ecto(%{"type" => "array", "items" => items}, _name, schema_path) do
    case items do
      %{"$ref" => ref} ->
        ref_module = ref_to_module_name(ref, schema_path)
        "Schemecto.many(#{ref_module}.fields(), with: &Function.identity/1)"

      %{"type" => inner_type} ->
        "{:array, #{json_primitive_type(inner_type)}}"

      _ ->
        "{:array, :map}"
    end
  end

  defp json_type_to_ecto(%{"type" => "string", "enum" => _values}, name, _schema_path) do
    "@#{name}_type"
  end

  defp json_type_to_ecto(%{"type" => "string", "format" => "date-time"}, _name, _schema_path) do
    ":utc_datetime"
  end

  defp json_type_to_ecto(%{"type" => "string", "format" => "uri"}, _name, _schema_path) do
    ":string"
  end

  defp json_type_to_ecto(%{"type" => type}, _name, _schema_path) do
    json_primitive_type(type)
  end

  defp json_type_to_ecto(%{"oneOf" => _}, _name, _schema_path), do: ":map"
  defp json_type_to_ecto(%{"allOf" => _}, _name, _schema_path), do: ":map"
  defp json_type_to_ecto(%{"anyOf" => _}, _name, _schema_path), do: ":map"
  defp json_type_to_ecto(_prop, _name, _schema_path), do: ":map"

  defp json_primitive_type("string"), do: ":string"
  defp json_primitive_type("integer"), do: ":integer"
  defp json_primitive_type("number"), do: ":float"
  defp json_primitive_type("boolean"), do: ":boolean"
  defp json_primitive_type("object"), do: ":map"
  defp json_primitive_type("array"), do: "{:array, :map}"
  defp json_primitive_type(_), do: ":map"

  defp resolve_ref(ref, schema_path) do
    schema_dir = Path.dirname(schema_path)

    ref
    |> String.replace(~r/#.*$/, "")
    |> then(&Path.expand(&1, schema_dir))
  end

  defp ref_to_module_name(ref, schema_path) do
    ref_path = resolve_ref(ref, schema_path)

    case find_schemas_base(ref_path) do
      {:ok, relative_path} ->
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
        |> then(&"Bazaar.Schemas.#{&1}")

      :error ->
        ref_path
        |> Path.basename(".json")
        |> Macro.camelize()
        |> then(&"Bazaar.Schemas.#{&1}")
    end
  end

  defp find_schemas_base(path) do
    case Regex.run(~r|ucp_schemas/[\d-]+/(.+)$|, path) do
      [_, relative] -> {:ok, relative}
      nil -> :error
    end
  end

  defp find_schemas_dir(schema_path) do
    case Regex.run(~r|^(.+/ucp_schemas)|, Path.expand(schema_path)) do
      [_, dir] -> dir
      nil -> Path.dirname(schema_path)
    end
  end

  defp generate_enum_types(properties) do
    properties
    |> Enum.filter(fn {_name, prop} ->
      prop["type"] == "string" && prop["enum"]
    end)
    |> Enum.map(fn {name, prop} ->
      values = prop["enum"] |> Enum.map(&String.to_atom/1) |> inspect()

      """
        @#{name}_values #{values}
        @#{name}_type Ecto.ParameterizedType.init(Ecto.Enum, values: @#{name}_values)
      """
    end)
    |> Enum.join("\n")
  end

  defp generate_required_validation([]), do: ""

  defp generate_required_validation(required) do
    "    |> validate_required(#{inspect(required)})"
  end

  defp infer_module_name(schema_path) do
    case find_schemas_base(Path.expand(schema_path)) do
      {:ok, relative_path} ->
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
        |> then(&"Bazaar.Schemas.#{&1}")

      :error ->
        schema_path
        |> Path.basename(".json")
        |> String.replace(~r/[._]/, " ")
        |> String.split()
        |> Enum.map(&String.capitalize/1)
        |> Enum.join()
        |> then(&"Bazaar.Schemas.#{&1}")
    end
  end
end
