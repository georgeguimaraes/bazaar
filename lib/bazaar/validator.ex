if Code.ensure_loaded?(JSV) do
  defmodule Bazaar.Validator do
    @moduledoc """
    Validates data against UCP and ACP schemas.

    UCP schemas (checkout, order, profile) are validated via JSV against the
    bundled JSON Schema files. ACP JSON schemas (checkout_session, delegate_payment_req,
    etc.) are validated via JSV against bundle schemas with `$defs`. The OpenAI product feed
    is validated via an Ecto embedded schema changeset.

    > #### Note {: .info}
    > This module requires the `jsv` dependency. Add `{:jsv, "~> 0.15"}` to your
    > mix.exs deps to use validation features.

    ## Usage

        case Bazaar.Validator.validate_checkout(checkout_data) do
          {:ok, validated} -> # Data conforms to spec
          {:error, errors} -> # Validation errors
        end

        # Or use validate/2 with any schema atom
        Bazaar.Validator.validate(data, :checkout_session)

    ## Available Validators

    - `validate_checkout/1` - UCP checkout session response
    - `validate_order/1` - UCP order response
    - `validate_profile/1` - UCP discovery profile
    - `validate_openai_product_feed/1` - OpenAI product feed
    - `validate/2` - Generic validation against any schema
    """

    @ucp_schemas_dir :code.priv_dir(:bazaar) |> Path.join("ucp_schemas/2026-01-23")
    @acp_schemas_dir :code.priv_dir(:bazaar) |> Path.join("acp_schemas")

    # ACP bundle schemas: {bundle_file, def_name}
    @acp_bundle_defs %{
      checkout_session: {"checkout.json", "CheckoutSession"},
      checkout_session_with_order: {"checkout.json", "CheckoutSessionWithOrder"},
      checkout_create_req: {"checkout.json", "CheckoutSessionCreateRequest"},
      checkout_update_req: {"checkout.json", "CheckoutSessionUpdateRequest"},
      checkout_complete_req: {"checkout.json", "CheckoutSessionCompleteRequest"},
      cancel_session_req: {"checkout.json", "CancelSessionRequest"},
      delegate_payment_req: {"delegate_payment.json", "DelegatePaymentRequest"},
      delegate_payment_resp: {"delegate_payment.json", "DelegatePaymentResponse"}
    }

    @ucp_schemas [:checkout, :order, :profile]
    @acp_bundle_schemas Map.keys(@acp_bundle_defs)

    # Convenience functions

    @doc """
    Validates data against the UCP checkout response schema.

    Returns `{:ok, data}` if valid, or `{:error, errors}` with validation errors.
    """
    def validate_checkout(data), do: validate(data, :checkout)

    @doc """
    Validates data against the UCP order schema.

    Returns `{:ok, data}` if valid, or `{:error, errors}` with validation errors.
    """
    def validate_order(data), do: validate(data, :order)

    @doc """
    Validates a UCP discovery profile (the `/.well-known/ucp` response).

    Returns `{:ok, data}` if valid, or `{:error, errors}` with validation errors.
    """
    def validate_profile(data), do: validate(data, :profile)

    @doc """
    Validates data against the OpenAI product feed schema.

    Based on the OpenAI developer docs product feed spec
    (developers.openai.com/commerce/specs/feed/). Validated via the
    `Bazaar.Schemas.Acp.ProductFeed` Ecto embedded schema.

    Returns `{:ok, struct}` if valid, or `{:error, errors}` with validation errors.
    """
    def validate_openai_product_feed(data), do: validate(data, :openai_product_feed)

    @doc """
    Validates data against a specific UCP or ACP schema.

    ## UCP schemas

    - `:checkout` - Checkout session response
    - `:order` - Order response
    - `:profile` - Discovery profile

    ## ACP schemas (from open ACP repo)

    - `:checkout_session` - Checkout session response
    - `:checkout_session_with_order` - Checkout session response with order
    - `:checkout_create_req` - Create checkout request
    - `:checkout_update_req` - Update checkout request
    - `:checkout_complete_req` - Complete checkout request
    - `:cancel_session_req` - Cancel session request
    - `:delegate_payment_req` - Delegate payment request
    - `:delegate_payment_resp` - Delegate payment response

    ## ACP schemas (OpenAI-specific)

    - `:openai_product_feed` - Product feed
    """
    def validate(data, :openai_product_feed) do
      changeset =
        Bazaar.Schemas.Acp.ProductFeed.changeset(%Bazaar.Schemas.Acp.ProductFeed{}, data)

      if changeset.valid? do
        {:ok, Ecto.Changeset.apply_changes(changeset)}
      else
        {:error, format_changeset_errors(changeset)}
      end
    end

    def validate(data, schema_name) when schema_name in @ucp_schemas do
      with {:ok, schema} <- get_ucp_schema(schema_name),
           {:ok, root} <- build_root(schema, @ucp_schemas_dir) do
        run_jsv(data, root)
      end
    end

    def validate(data, schema_name) when schema_name in @acp_bundle_schemas do
      {bundle_file, def_name} = @acp_bundle_defs[schema_name]

      with {:ok, schema} <- get_acp_def_schema(bundle_file, def_name),
           {:ok, root} <- build_root(schema, @acp_schemas_dir) do
        run_jsv(data, root)
      end
    end

    @doc """
    Returns the raw JSON schema for a given UCP schema name.
    """
    def get_schema(schema_name) when schema_name in @ucp_schemas do
      get_ucp_schema(schema_name)
    end

    @doc """
    Lists all available schemas bundled with Bazaar, grouped by protocol.
    """
    def available_schemas do
      %{
        ucp: @ucp_schemas,
        acp: @acp_bundle_schemas ++ [:openai_product_feed]
      }
    end

    # Private: JSV execution

    defp run_jsv(data, root) do
      case JSV.validate(data, root) do
        {:ok, validated} -> {:ok, validated}
        {:error, error} -> {:error, normalize_errors(error)}
      end
    end

    defp build_root(schema, schemas_dir) do
      resolver = {Bazaar.Validator.Resolver, schemas_dir: schemas_dir}

      case JSV.build(schema, resolver: resolver) do
        {:ok, root} -> {:ok, root}
        {:error, error} -> {:error, {:schema_build_error, error}}
      end
    end

    # Private: UCP schema loading

    defp get_ucp_schema(schema_name) do
      ucp_schema_path(schema_name)
      |> File.read()
      |> case do
        {:ok, content} -> JSON.decode(content)
        {:error, reason} -> {:error, {:file_read_error, reason}}
      end
    end

    defp ucp_schema_path(:checkout),
      do: Path.join([@ucp_schemas_dir, "shopping", "checkout_resp.json"])

    defp ucp_schema_path(:order), do: Path.join([@ucp_schemas_dir, "shopping", "order.json"])
    defp ucp_schema_path(:profile), do: Path.join(@ucp_schemas_dir, "profile.json")

    # Private: ACP bundle schema loading

    defp get_acp_def_schema(bundle_file, def_name) do
      path = Path.join(@acp_schemas_dir, bundle_file)

      with {:ok, content} <- File.read(path),
           {:ok, bundle} <- JSON.decode(content) do
        {:ok, %{"$defs" => bundle["$defs"], "$ref" => "#/$defs/#{def_name}"}}
      else
        {:error, reason} when is_atom(reason) -> {:error, {:file_read_error, reason}}
        {:error, _} = error -> error
      end
    end

    # Private: error formatting

    defp normalize_errors(%JSV.ValidationError{} = error) do
      JSV.normalize_error(error)
    end

    defp normalize_errors(error), do: error

    defp format_changeset_errors(changeset) do
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)
    end
  end
end
