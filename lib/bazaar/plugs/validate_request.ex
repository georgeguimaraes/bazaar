defmodule Bazaar.Plugs.ValidateRequest do
  @moduledoc """
  Plug that validates incoming UCP requests against schemas.

  Uses Smelter-generated Ecto schemas to validate request bodies before
  they reach the handler. Invalid requests are rejected with a 422 response.

  ## Usage

      pipeline :bazaar_api do
        plug Bazaar.Plugs.ValidateRequest
      end

  ## Options

  - `:schemas` - Map of action atoms to schema modules (optional, uses defaults)
  - `:enabled` - Whether validation is enabled (default: true)

  ## Example

      plug Bazaar.Plugs.ValidateRequest,
        schemas: %{
          create_checkout: MyApp.Schemas.CustomCheckoutReq
        }

  ## Default Schemas

  - `create_checkout` -> `Bazaar.Schemas.Shopping.CheckoutCreateReq`
  - `update_checkout` -> `Bazaar.Schemas.Shopping.CheckoutUpdateReq`
  """

  import Plug.Conn

  alias Bazaar.Telemetry

  @behaviour Plug

  @default_schemas %{
    create_checkout: Bazaar.Schemas.Shopping.CheckoutCreateReq,
    update_checkout: Bazaar.Schemas.Shopping.CheckoutUpdateReq
  }

  @impl true
  def init(opts) do
    schemas = Keyword.get(opts, :schemas, %{})
    enabled = Keyword.get(opts, :enabled, true)

    %{
      schemas: Map.merge(@default_schemas, schemas),
      enabled: enabled
    }
  end

  @impl true
  def call(conn, %{enabled: false}), do: conn

  def call(conn, %{schemas: schemas}) do
    action = Phoenix.Controller.action_name(conn)

    case Map.fetch(schemas, action) do
      {:ok, schema_module} ->
        Telemetry.span_with_metadata(
          [:bazaar, :plug, :validate_request],
          %{action: action, schema: schema_module},
          fn ->
            validate_with_schema(conn, schema_module, action)
          end
        )

      :error ->
        # No schema for this action, pass through
        conn
    end
  end

  defp validate_with_schema(conn, schema_module, action) do
    params = conn.params

    case schema_module.new(params) do
      %{valid?: true} = changeset ->
        validated_data = Ecto.Changeset.apply_changes(changeset)

        result =
          conn
          |> assign(:bazaar_validated, true)
          |> assign(:bazaar_validated_action, action)
          |> assign(:bazaar_data, validated_data)

        {result, %{valid: true, action: action}}

      %{valid?: false} = changeset ->
        errors = Bazaar.Errors.from_changeset(changeset)

        result =
          conn
          |> put_status(:unprocessable_entity)
          |> Phoenix.Controller.json(errors)
          |> halt()

        {result, %{valid: false, action: action, error_count: length(errors["errors"] || [])}}
    end
  end
end
