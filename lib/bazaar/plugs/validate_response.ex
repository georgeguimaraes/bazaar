defmodule Bazaar.Plugs.ValidateResponse do
  @moduledoc """
  Plug that validates outgoing UCP responses against schemas.

  Uses Smelter-generated Ecto schemas to validate response bodies before
  they are sent to the client. Invalid responses are logged but still sent
  (in production) or can raise (in dev/test).

  ## Usage

      pipeline :bazaar_api do
        plug Bazaar.Plugs.ValidateResponse
      end

  ## Options

  - `:schemas` - Map of action atoms to schema modules (optional, uses defaults)
  - `:enabled` - Whether validation is enabled (default: true)
  - `:strict` - Raise on validation failure instead of logging (default: false)

  ## Example

      plug Bazaar.Plugs.ValidateResponse,
        strict: Application.compile_env(:my_app, :strict_validation, false)

      # Or with custom schemas
      plug Bazaar.Plugs.ValidateResponse,
        schemas: %{
          create_checkout: MyApp.Schemas.CustomCheckoutResp
        },
        strict: true

  ## Default Schemas

  - `create_checkout` -> `Bazaar.Schemas.Shopping.CheckoutResp`
  - `get_checkout` -> `Bazaar.Schemas.Shopping.CheckoutResp`
  - `update_checkout` -> `Bazaar.Schemas.Shopping.CheckoutResp`
  - `complete_checkout` -> `Bazaar.Schemas.Shopping.CheckoutResp`
  - `cancel_checkout` -> `Bazaar.Schemas.Shopping.CheckoutResp`
  - `get_order` -> `Bazaar.Schemas.Shopping.Order`
  - `cancel_order` -> `Bazaar.Schemas.Shopping.Order`
  """

  import Plug.Conn

  require Logger

  alias Bazaar.Telemetry

  @behaviour Plug

  @default_schemas %{
    create_checkout: Bazaar.Schemas.Shopping.CheckoutResp,
    get_checkout: Bazaar.Schemas.Shopping.CheckoutResp,
    update_checkout: Bazaar.Schemas.Shopping.CheckoutResp,
    complete_checkout: Bazaar.Schemas.Shopping.CheckoutResp,
    cancel_checkout: Bazaar.Schemas.Shopping.CheckoutResp,
    get_order: Bazaar.Schemas.Shopping.Order,
    cancel_order: Bazaar.Schemas.Shopping.Order
  }

  @impl true
  def init(opts) do
    schemas = Keyword.get(opts, :schemas, %{})
    enabled = Keyword.get(opts, :enabled, true)
    strict = Keyword.get(opts, :strict, false)

    %{
      schemas: Map.merge(@default_schemas, schemas),
      enabled: enabled,
      strict: strict
    }
  end

  @impl true
  def call(conn, %{enabled: false}), do: conn

  def call(conn, opts) do
    register_before_send(conn, fn conn ->
      validate_response(conn, opts)
    end)
  end

  defp validate_response(conn, %{schemas: schemas, strict: strict}) do
    action = conn.private[:phoenix_action]

    # Only validate successful responses (2xx status codes) with a known action
    if action && conn.status in 200..299 do
      case Map.fetch(schemas, action) do
        {:ok, schema_module} ->
          do_validate(conn, schema_module, action, strict)

        :error ->
          conn
      end
    else
      conn
    end
  end

  defp do_validate(conn, schema_module, action, strict) do
    case Jason.decode(conn.resp_body) do
      {:ok, body} ->
        Telemetry.span_with_metadata(
          [:bazaar, :plug, :validate_response],
          %{action: action, schema: schema_module},
          fn ->
            validate_body(conn, body, schema_module, action, strict)
          end
        )

      {:error, _} ->
        # Can't decode response body, skip validation
        conn
    end
  end

  defp validate_body(conn, body, schema_module, action, strict) do
    case schema_module.new(body) do
      %{valid?: true} ->
        {conn, %{valid: true, action: action}}

      %{valid?: false} = changeset ->
        errors = format_errors(changeset)

        if strict do
          raise Bazaar.Plugs.ValidateResponse.ValidationError,
            action: action,
            schema: schema_module,
            errors: errors
        else
          Logger.warning("[Bazaar] Response validation failed for #{action}: #{inspect(errors)}")

          {conn, %{valid: false, action: action, error_count: map_size(errors)}}
        end
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defmodule ValidationError do
    @moduledoc """
    Exception raised when response validation fails in strict mode.
    """
    defexception [:action, :schema, :errors]

    @impl true
    def message(%{action: action, schema: schema, errors: errors}) do
      "Response validation failed for #{action} (#{schema}):\n#{inspect(errors, pretty: true)}"
    end
  end
end
