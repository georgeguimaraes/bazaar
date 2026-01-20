defmodule Smelter.Generator.Schemecto do
  @moduledoc """
  Generates Schemecto-compatible Elixir modules from resolved JSON Schemas.

  Uses Elixir AST for code generation, then converts to string via Macro.to_string/1.

  Produces modules with:
  - `@fields` module attribute with field definitions
  - `fields/0` function returning field definitions
  - `new/1` function creating changesets with validation
  - Enum type attributes for string enums
  """

  alias Smelter.TypeMapper

  @doc """
  Generates Elixir module code from a resolved schema.

  ## Options

  - `:module` - Full module name
  - `:module_prefix` - Prefix for inferred module names (default: "Smelter.Generated")
  """
  @spec generate(map(), keyword()) :: String.t()
  def generate(schema, opts \\ []) do
    module_name = opts[:module] || infer_module_name(schema, opts)
    module_atom = String.to_atom("Elixir.#{module_name}")

    properties = schema["properties"] || %{}
    required = schema["required"] || []

    # Process properties to get fields and enum definitions
    {enum_attrs, fields} = process_properties(properties)
    required_atoms = Enum.map(required, &String.to_atom/1)

    # Build the module AST
    ast = build_module_ast(module_atom, schema, enum_attrs, fields, required_atoms)

    # Convert to string and format
    ast
    |> Macro.to_string()
    |> Code.format_string!()
    |> IO.iodata_to_binary()
    |> post_process()
  end

  # Post-process the generated code for better formatting
  # Only needed for heredoc conversion - parens are fixed at AST level
  defp post_process(code) do
    # Convert escaped moduledoc strings to heredocs for readability
    convert_moduledoc_to_heredoc(code)
  end

  # Convert @moduledoc "string with \n" to @moduledoc heredoc
  defp convert_moduledoc_to_heredoc(code) do
    # Match @moduledoc followed by a double-quoted string (potentially with escaped chars)
    Regex.replace(
      ~r/@moduledoc "((?:[^"\\]|\\.)*)"/,
      code,
      fn _, content ->
        # Unescape the string
        unescaped =
          content
          |> String.replace("\\n", "\n")
          |> String.replace("\\\"", "\"")
          |> String.replace("\\\\", "\\")

        # Indent each line properly
        indented =
          unescaped
          |> String.split("\n")
          |> Enum.join("\n  ")

        ~s|@moduledoc """\n  #{indented}\n  """|
      end
    )
  end

  # Build the complete module AST
  defp build_module_ast(module_atom, schema, enum_attrs, fields, required_atoms) do
    moduledoc = build_moduledoc(schema)
    enum_attr_asts = build_enum_attrs(enum_attrs)
    fields_ast = build_fields_ast(fields)
    new_fn_ast = build_new_fn_ast(required_atoms)

    # Build body as flat list - avoid nested blocks that cause extra parens
    {new_doc, new_def} = new_fn_ast

    body =
      [
        moduledoc,
        quote(do: import(Ecto.Changeset))
      ] ++
        enum_attr_asts ++
        [
          fields_ast,
          quote(do: @doc("Returns the field definitions for this schema.")),
          quote(do: def(fields, do: @fields)),
          new_doc,
          new_def
        ]

    {:defmodule, [context: Elixir],
     [
       {:__aliases__, [alias: false], module_parts(module_atom)},
       [do: {:__block__, [], body}]
     ]}
  end

  # Extract module name parts for AST
  defp module_parts(module_atom) do
    module_atom
    |> Atom.to_string()
    |> String.replace_prefix("Elixir.", "")
    |> String.split(".")
    |> Enum.map(&String.to_atom/1)
  end

  # Build @moduledoc attribute - returns {doc_content, ast}
  # We return the content separately so we can format it as heredoc in post-processing
  defp build_moduledoc(schema) do
    title = schema["title"] || "Schema"
    description = schema["description"]

    source =
      case schema[:_source_path] do
        nil -> ""
        path -> "\n\nGenerated from: #{Path.basename(path)}"
      end

    doc_content =
      if description do
        "#{title}\n\n#{description}#{source}"
      else
        "#{title}#{source}"
      end

    # Build a placeholder that we'll replace in post-processing
    {:@, [context: Elixir], [{:moduledoc, [context: Elixir], [doc_content]}]}
  end

  # Build enum module attributes
  defp build_enum_attrs([]), do: []

  defp build_enum_attrs(enum_attrs) do
    Enum.flat_map(enum_attrs, fn {name, values} ->
      values_attr = String.to_atom("#{name}_values")
      type_attr = String.to_atom("#{name}_type")
      atom_values = Enum.map(values, &to_safe_atom/1)

      [
        {:@, [context: Elixir], [{values_attr, [context: Elixir], [atom_values]}]},
        {:@, [context: Elixir],
         [
           {type_attr, [context: Elixir],
            [
              quote do
                Ecto.ParameterizedType.init(Ecto.Enum,
                  values: unquote({:@, [], [{values_attr, [], nil}]})
                )
              end
            ]}
         ]}
      ]
    end)
  end

  # Build @fields attribute with field definitions
  defp build_fields_ast(fields) do
    field_maps =
      Enum.map(fields, fn field ->
        # Build map pairs as AST - type is already AST, others need escaping
        pairs = [
          {Macro.escape(:name), Macro.escape(String.to_atom(field.name))},
          {Macro.escape(:type), field.type_ast}
        ]

        pairs =
          if field.description do
            pairs ++ [{Macro.escape(:description), Macro.escape(field.description)}]
          else
            pairs
          end

        pairs =
          if field.default do
            pairs ++ [{Macro.escape(:default), Macro.escape(field.default)}]
          else
            pairs
          end

        # Build %{key: value, ...} AST
        {:%{}, [], pairs}
      end)

    {:@, [context: Elixir], [{:fields, [context: Elixir], [field_maps]}]}
  end

  # Build new/1 function - returns {doc_ast, def_ast} to keep them separate
  defp build_new_fn_ast([]) do
    doc = quote(do: @doc("Creates a new changeset from params."))

    def_ast =
      quote do
        def new(params \\ %{}) do
          Schemecto.new(@fields, params)
        end
      end

    {doc, def_ast}
  end

  defp build_new_fn_ast(required_atoms) do
    doc = quote(do: @doc("Creates a new changeset from params."))

    def_ast =
      quote do
        def new(params \\ %{}) do
          Schemecto.new(@fields, params)
          |> validate_required(unquote(required_atoms))
        end
      end

    {doc, def_ast}
  end

  # Process properties and extract enum definitions
  defp process_properties(properties) do
    properties
    |> Enum.sort_by(fn {name, _} -> name end)
    |> Enum.map_reduce([], fn {name, prop}, enum_defs ->
      {type, type_opts} = TypeMapper.map_type(prop)

      # Handle enum types specially - create module attributes
      {type_ast, new_enum_defs} =
        case type do
          :enum ->
            values = type_opts[:values]
            type_attr = String.to_atom("#{name}_type")
            ast = {:@, [], [{type_attr, [], nil}]}
            {ast, [{name, values} | enum_defs]}

          :const ->
            value = type_opts[:value]
            type_attr = String.to_atom("#{name}_type")
            ast = {:@, [], [{type_attr, [], nil}]}
            {ast, [{name, [value]} | enum_defs]}

          _ ->
            {TypeMapper.to_type_ast({type, type_opts}), enum_defs}
        end

      field = %{
        name: name,
        type_ast: type_ast,
        description: prop["description"],
        default: type_opts[:default]
      }

      {field, new_enum_defs}
    end)
    |> then(fn {fields, enum_defs} ->
      {Enum.reverse(enum_defs), fields}
    end)
  end

  # Convert string to safe atom
  defp to_safe_atom(value) when is_binary(value), do: String.to_atom(value)
  defp to_safe_atom(value), do: value

  # Infer module name from schema
  defp infer_module_name(schema, opts) do
    prefix = opts[:module_prefix] || "Smelter.Generated"

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
