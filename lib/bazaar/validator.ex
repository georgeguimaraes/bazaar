if Code.ensure_loaded?(JSV) do
  defmodule Bazaar.Validator do
    @moduledoc """
    Validates data against UCP and ACP JSON Schemas using JSV.

    This module provides validation against the official UCP schemas from
    the Universal Commerce Protocol specification, as well as ACP (Agentic
    Commerce Protocol) schemas from OpenAI's developer docs. Use this during
    development and testing to ensure your responses conform to the specs.

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
          {:ok, validated} -> # Data conforms to spec
          {:error, errors} -> # Validation errors
        end

    ## Available Validators

    - `validate_checkout/1` - Validates checkout session responses
    - `validate_order/1` - Validates order responses
    - `validate_product_feed/1` - Validates OpenAI product feed data
    - `validate/2` - Generic validation against any UCP/ACP schema
    """

    @schemas_dir :code.priv_dir(:bazaar) |> Path.join("ucp_schemas/2026-01-23")
    @openai_schemas_dir :code.priv_dir(:bazaar) |> Path.join("acp_schemas/openai")

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
    Validates a UCP discovery profile (the `/.well-known/ucp` response).

    Returns `{:ok, data}` if valid, or `{:error, errors}` with validation errors.

    ## Example

        {:ok, profile} = Bazaar.Validator.validate_profile(discovery_json)
    """
    def validate_profile(data) do
      validate(data, :profile)
    end

    @doc """
    Validates data against the ACP product feed schema.

    Based on the OpenAI developer docs product feed spec
    (developers.openai.com/commerce/specs/feed/). Not yet in the open ACP repo.

    Returns `{:ok, data}` if valid, or `{:error, errors}` with validation errors.
    """
    def validate_product_feed(data) do
      validate(data, :product_feed)
    end

    @doc """
    Validates data against a specific UCP or ACP schema.

    ## Supported schemas

    - `:checkout` - UCP checkout session response schema
    - `:order` - UCP order response schema
    - `:profile` - UCP discovery profile schema
    - `:product_feed` - ACP product feed schema (OpenAI)

    ## Examples

        iex> Bazaar.Validator.validate(%{"id" => "123"}, :checkout)
        {:error, [...]}  # Missing required fields
    """
    def validate(data, schema_name)
        when schema_name in [:checkout, :order, :profile, :product_feed] do
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
    def get_schema(schema_name)
        when schema_name in [:checkout, :order, :profile, :product_feed] do
      schema_path(schema_name)
      |> File.read()
      |> case do
        {:ok, content} -> JSON.decode(content)
        {:error, reason} -> {:error, {:file_read_error, reason}}
      end
    end

    @doc """
    Lists all available schemas (UCP and ACP) bundled with Bazaar.
    """
    def available_schemas do
      [:checkout, :order, :profile, :product_feed]
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
    defp schema_path(:profile), do: Path.join([@schemas_dir, "profile.json"])
    defp schema_path(:product_feed), do: Path.join(@openai_schemas_dir, "product_feed.json")

    defp normalize_errors(%JSV.ValidationError{} = error) do
      JSV.normalize_error(error)
    end

    defp normalize_errors(error), do: error
  end
end
