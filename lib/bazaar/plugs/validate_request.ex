defmodule Bazaar.Plugs.ValidateRequest do
  @moduledoc """
  Plug that validates incoming UCP requests against schemas.

  ## Usage

      pipeline :ucp do
        plug Bazaar.Plugs.ValidateRequest
      end

  ## Options

  - `:schemas` - Map of action atoms to schema modules (optional, uses defaults)

  ## Example

      plug Bazaar.Plugs.ValidateRequest,
        schemas: %{
          create_checkout: MyApp.Schemas.CustomCheckout
        }
  """

  import Plug.Conn

  @behaviour Plug

  @default_schemas %{
    create_checkout: Bazaar.Schemas.CheckoutSession,
    update_checkout: Bazaar.Schemas.CheckoutSession
  }

  @impl true
  def init(opts) do
    schemas = Keyword.get(opts, :schemas, %{})
    Map.merge(@default_schemas, schemas)
  end

  @impl true
  def call(conn, schemas) do
    action = Phoenix.Controller.action_name(conn)

    case Map.fetch(schemas, action) do
      {:ok, schema_module} ->
        validate_with_schema(conn, schema_module)

      :error ->
        # No schema for this action, pass through
        conn
    end
  end

  defp validate_with_schema(conn, schema_module) do
    params = conn.params

    case schema_module.new(params) do
      %{valid?: true} = changeset ->
        validated_data = Ecto.Changeset.apply_changes(changeset)

        conn
        |> assign(:bazaar_validated, true)
        |> assign(:bazaar_data, validated_data)

      %{valid?: false} = changeset ->
        errors = Bazaar.Errors.from_changeset(changeset)

        conn
        |> put_status(:unprocessable_entity)
        |> Phoenix.Controller.json(errors)
        |> halt()
    end
  end
end
