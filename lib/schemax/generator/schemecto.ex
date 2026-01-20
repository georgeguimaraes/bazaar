defmodule Schemax.Generator.Schemecto do
  @moduledoc """
  Generates Schemecto-compatible Elixir modules from resolved JSON Schemas.

  Produces modules with:
  - `@fields` module attribute with field definitions
  - `fields/0` function returning field definitions
  - `new/1` function creating changesets with validation
  - Enum type attributes for string enums
  """

  alias Schemax.TypeMapper

  @doc """
  Generates Elixir module code from a resolved schema.

  ## Options

  - `:module` - Full module name
  - `:module_prefix` - Prefix for inferred module names (default: "Schemax.Generated")
  """
  @spec generate(map(), keyword()) :: String.t()
  def generate(schema, opts \\ []) do
    module_name = opts[:module] || infer_module_name(schema, opts)
    title = schema["title"] || "Schema"
    description = schema["description"]
    properties = schema["properties"] || %{}
    required = schema["required"] || []

    # Pre-process properties to extract enum types
    {enum_definitions, fields} = process_properties(properties, opts)
    required_atoms = Enum.map(required, &String.to_atom/1)

    source_path =
      case schema[:_source_path] do
        nil -> ""
        path -> "\n  Generated from: #{Path.basename(path)}"
      end

    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      #{title}#{if description, do: "\\n\\n  #{description}", else: ""}
    #{source_path}
      \"\"\"

      import Ecto.Changeset

    #{enum_definitions}  @fields [
    #{format_fields(fields)}
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

  # Process properties and extract enum definitions
  defp process_properties(properties, _opts) do
    properties
    |> Enum.sort_by(fn {name, _} -> name end)
    |> Enum.map_reduce([], fn {name, prop}, enum_defs ->
      {type, type_opts} = TypeMapper.map_type(prop)

      # Handle enum types specially - create module attributes
      {type_str, new_enum_defs} =
        case type do
          :enum ->
            values = type_opts[:values]
            {generate_enum_type_ref(name), [{name, values} | enum_defs]}

          :const ->
            value = type_opts[:value]
            {generate_enum_type_ref(name), [{name, [value]} | enum_defs]}

          _ ->
            {TypeMapper.to_ecto_type({type, type_opts}), enum_defs}
        end

      field = %{
        name: name,
        type: type_str,
        description: prop["description"],
        default: type_opts[:default]
      }

      {field, new_enum_defs}
    end)
    |> then(fn {fields, enum_defs} ->
      enum_str = generate_enum_definitions(Enum.reverse(enum_defs))
      {enum_str, fields}
    end)
  end

  # Generate enum module attributes
  defp generate_enum_definitions([]), do: ""

  defp generate_enum_definitions(enum_defs) do
    enum_defs
    |> Enum.map(fn {name, values} ->
      atoms = values |> Enum.map(&to_safe_atom/1) |> inspect()

      """
        @#{name}_values #{atoms}
        @#{name}_type Ecto.ParameterizedType.init(Ecto.Enum, values: @#{name}_values)
      """
    end)
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  # Generate reference to enum type attribute
  defp generate_enum_type_ref(name), do: "@#{name}_type"

  # Convert string to safe atom
  defp to_safe_atom(value) when is_binary(value), do: String.to_atom(value)
  defp to_safe_atom(value), do: value

  # Format fields as Elixir code
  defp format_fields(fields) do
    fields
    |> Enum.map(&format_field/1)
    |> Enum.map(&"    #{&1}")
    |> Enum.join(",\n")
  end

  # Format a single field
  defp format_field(field) do
    parts =
      [
        "name: :#{field.name}",
        "type: #{field.type}"
      ] ++
        if(field.description, do: ["description: #{inspect(field.description)}"], else: []) ++
        if(field.default, do: ["default: #{inspect(field.default)}"], else: [])

    "%{#{Enum.join(parts, ", ")}}"
  end

  # Generate required field validation
  defp generate_required_validation([]), do: ""

  defp generate_required_validation(required) do
    "    |> validate_required(#{inspect(required)})"
  end

  # Infer module name from schema
  defp infer_module_name(schema, opts) do
    prefix = opts[:module_prefix] || "Schemax.Generated"

    name =
      cond do
        schema[:_source_path] ->
          schema[:_source_path]
          |> Path.basename(".json")
          |> String.replace(~r/[._]/, " ")
          |> String.split()
          |> Enum.map(&String.capitalize/1)
          |> Enum.join()

        schema["title"] ->
          schema["title"]
          |> String.replace(~r/[^a-zA-Z0-9\s]/, "")
          |> String.split()
          |> Enum.map(&String.capitalize/1)
          |> Enum.join()

        true ->
          "Schema"
      end

    "#{prefix}.#{name}"
  end
end
