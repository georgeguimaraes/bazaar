if Code.ensure_loaded?(JSV) do
  defmodule Bazaar.Validator do
    @moduledoc """
    Validates data against official UCP JSON Schemas using JSV.

    This module provides validation against the official UCP schemas from
    the Universal Commerce Protocol specification. Use this during development
    and testing to ensure your responses conform to the UCP spec.

    > #### Note {: .info}
    > This module requires the `jsv` dependency. Add `{:jsv, "~> 0.15"}` to your
    > mix.exs deps to use validation features.

    ## Usage

        # Validate a checkout response
        checkout_data = %{
          "id" => "checkout_123",
          "status" => "incomplete",
          "currency" => "USD",
          # ...
        }

        case Bazaar.Validator.validate_checkout(checkout_data) do
          {:ok, validated} -> # Data conforms to UCP spec
          {:error, errors} -> # Validation errors
        end

    ## Available Validators

    - `validate_checkout/1` - Validates checkout session responses
    - `validate_order/1` - Validates order responses
    - `validate/2` - Generic validation against any UCP schema
    """

    @schemas_dir :code.priv_dir(:bazaar) |> Path.join("ucp_schemas")

    @doc """
    Validates data against the UCP checkout response schema.

    Returns `{:ok, data}` if valid, or `{:error, errors}` with validation errors.
    """
    def validate_checkout(data) do
      validate(data, :checkout)
    end

    @doc """
    Validates data against the UCP order schema.

    Returns `{:ok, data}` if valid, or `{:error, errors}` with validation errors.
    """
    def validate_order(data) do
      validate(data, :order)
    end

    @doc """
    Validates data against a specific UCP schema.

    ## Supported schemas

    - `:checkout` - Checkout session response schema
    - `:order` - Order response schema

    ## Examples

        iex> Bazaar.Validator.validate(%{"id" => "123"}, :checkout)
        {:error, [...]}  # Missing required fields
    """
    def validate(data, schema_name) when schema_name in [:checkout, :order] do
      case get_root(schema_name) do
        {:ok, root} ->
          case JSV.validate(data, root) do
            {:ok, validated} -> {:ok, validated}
            {:error, error} -> {:error, normalize_errors(error)}
          end

        {:error, _} = error ->
          error
      end
    end

    @doc """
    Returns the raw JSON schema for a given schema name.

    Useful for documentation or custom validation scenarios.
    """
    def get_schema(schema_name) when schema_name in [:checkout, :order] do
      schema_path(schema_name)
      |> File.read()
      |> case do
        {:ok, content} -> Jason.decode(content)
        {:error, reason} -> {:error, {:file_read_error, reason}}
      end
    end

    @doc """
    Lists all available UCP schemas bundled with Bazaar.
    """
    def available_schemas do
      [:checkout, :order]
    end

    # Private functions

    defp get_root(schema_name) do
      case get_schema(schema_name) do
        {:ok, schema} ->
          resolver = {Bazaar.Validator.Resolver, schemas_dir: @schemas_dir}

          case JSV.build(schema, resolver: resolver) do
            {:ok, root} -> {:ok, root}
            {:error, error} -> {:error, {:schema_build_error, error}}
          end

        {:error, _} = error ->
          error
      end
    end

    defp schema_path(:checkout), do: Path.join([@schemas_dir, "shopping", "checkout_resp.json"])
    defp schema_path(:order), do: Path.join([@schemas_dir, "shopping", "order.json"])

    defp normalize_errors(%JSV.ValidationError{} = error) do
      JSV.normalize_error(error)
    end

    defp normalize_errors(error), do: error
  end
end
