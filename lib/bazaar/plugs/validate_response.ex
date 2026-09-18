defmodule Bazaar.Plugs.ValidateResponse do
  @moduledoc """
  Plug that validates outgoing UCP responses against the spec's JSON
  Schemas, through `Bazaar.Validator`, before they are sent. Invalid
  responses are logged but still sent, or raise with `strict: true` (dev and
  test). Needs the optional `jsv` dependency.

  ## Usage

      pipeline :bazaar_api do
        plug Bazaar.Plugs.ValidateResponse, strict: Mix.env() != :prod
      end

  ## Options

  - `:schemas` - Map of action atoms to schemas: a `Bazaar.Validator` schema
    name (`:checkout`, `:cart`, `:order`, `:catalog_search_response`, ...) or
    any module with a `new/1` returning an `Ecto.Changeset`, such as the
    Smelter-generated ones. Merged over the defaults.
  - `:enabled` - Whether validation is enabled (default: true)
  - `:strict` - Raise on validation failure instead of logging (default: false)

  ## Default schemas

  Checkout actions validate as `:checkout`, cart actions as `:cart`, order
  actions as `:order`, and the catalog actions as `:catalog_search_response`,
  `:catalog_lookup_response` and `:catalog_product_response`. The spec's
  error document (`ucp.status: "error"`) is let through at any status.

  On routes mounted with `protocol: :acp` the checkout actions validate as
  `:checkout_session` instead (ACP's with-order schema composes a closed
  object with `order`, which nothing can satisfy, so `order` is set aside).
  """

  import Plug.Conn

  require Logger

  alias Bazaar.Telemetry

  @behaviour Plug

  @default_schemas %{
    create_checkout: :checkout,
    get_checkout: :checkout,
    update_checkout: :checkout,
    complete_checkout: :checkout,
    cancel_checkout: :checkout,
    create_cart: :cart,
    get_cart: :cart,
    update_cart: :cart,
    cancel_cart: :cart,
    get_order: :order,
    cancel_order: :order,
    search_products: :catalog_search_response,
    lookup_products: :catalog_lookup_response,
    get_product: :catalog_product_response,
    search_locations: :location_search_response,
    lookup_locations: :location_lookup_response
  }

  @acp_schemas %{
    create_checkout: :checkout_session,
    get_checkout: :checkout_session,
    update_checkout: :checkout_session,
    complete_checkout: :checkout_session,
    cancel_checkout: :checkout_session
  }

  @impl true
  def init(opts) do
    schemas = Map.merge(@default_schemas, Keyword.get(opts, :schemas, %{}))

    unless Code.ensure_loaded?(Bazaar.Validator) or
             Enum.all?(schemas, &changeset_module?(elem(&1, 1))) do
      raise ArgumentError,
            "Bazaar.Plugs.ValidateResponse validates against the spec's JSON Schemas, " <>
              "which needs the jsv dependency: add {:jsv, \"~> 0.15\"} to your deps"
    end

    %{
      schemas: schemas,
      enabled: Keyword.get(opts, :enabled, true),
      strict: Keyword.get(opts, :strict, false)
    }
  end

  defp changeset_module?(schema),
    do: Code.ensure_loaded?(schema) and function_exported?(schema, :new, 1)

  @impl true
  def call(conn, %{enabled: false}), do: conn

  def call(conn, opts) do
    register_before_send(conn, fn conn ->
      validate_response(conn, opts)
    end)
  end

  defp validate_response(conn, %{schemas: schemas, strict: strict}) do
    action = conn.private[:phoenix_action]
    schemas = if conn.assigns[:bazaar_protocol] == :acp, do: @acp_schemas, else: schemas

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

  # The spec's error document can travel at 200 (catalog get product for an
  # unknown id); it is not the action's response shape.
  defp validate_body(conn, %{"ucp" => %{"status" => "error"}}, _schema_module, action, _strict) do
    {conn, %{valid: true, action: action, skipped: :error_document}}
  end

  defp validate_body(conn, body, :checkout_session, action, strict),
    do: validate_body(conn, Map.delete(body, "order"), {:acp, :checkout_session}, action, strict)

  defp validate_body(conn, body, schema, action, strict) do
    schema = with {:acp, name} <- schema, do: name

    case validate(body, schema) do
      :ok ->
        {conn, %{valid: true, action: action}}

      {:error, errors} ->
        if strict do
          raise Bazaar.Plugs.ValidateResponse.ValidationError,
            action: action,
            schema: schema,
            errors: errors
        else
          Logger.warning("[Bazaar] Response validation failed for #{action}: #{inspect(errors)}")

          {conn, %{valid: false, action: action, error_count: length(errors)}}
        end
    end
  end

  # Errors come back as a flat list of messages, whichever validator produced them.
  defp validate(body, schema) do
    if changeset_module?(schema) do
      case schema.new(body) do
        %{valid?: true} ->
          :ok

        changeset ->
          {:error,
           Enum.map(
             Bazaar.Errors.changeset_details(changeset),
             &"#{&1["field"]} #{&1["message"]}"
           )}
      end
    else
      case Bazaar.Validator.validate(body, schema) do
        {:ok, _} -> :ok
        {:error, %{details: details}} -> {:error, jsv_messages(details)}
        {:error, other} -> {:error, [inspect(other)]}
      end
    end
  end

  # JSV nests details inside composition errors (allOf, $ref); the leaves say what failed.
  defp jsv_messages(details) do
    for %{instanceLocation: at, errors: errors} <- details,
        error <- errors,
        message <- leaves(at, error) do
      message
    end
  end

  defp leaves(_at, %{details: [_ | _] = nested}), do: jsv_messages(nested)
  defp leaves(at, %{message: message}), do: ["#{at}: #{message}"]

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
