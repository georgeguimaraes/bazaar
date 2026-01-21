defmodule Bazaar.Plugs.ValidateRequestTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  alias Bazaar.Plugs.ValidateRequest

  # Custom schema for testing
  defmodule CustomSchema do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field(:name, :string)
      field(:amount, :integer)
    end

    def changeset(struct \\ %__MODULE__{}, params) do
      struct
      |> cast(params, [:name, :amount])
      |> validate_required([:name, :amount])
      |> validate_number(:amount, greater_than: 0)
    end

    def new(params), do: changeset(params)
  end

  describe "init/1" do
    test "uses empty default schemas when none provided" do
      opts = ValidateRequest.init([])

      assert opts.schemas == %{}
      assert opts.enabled == true
    end

    test "accepts custom schemas" do
      custom_schemas = %{create_checkout: CustomSchema}
      opts = ValidateRequest.init(schemas: custom_schemas)

      assert opts.schemas[:create_checkout] == CustomSchema
    end

    test "allows adding multiple action schemas" do
      custom_schemas = %{custom_action: CustomSchema, another_action: CustomSchema}
      opts = ValidateRequest.init(schemas: custom_schemas)

      assert opts.schemas[:custom_action] == CustomSchema
      assert opts.schemas[:another_action] == CustomSchema
    end

    test "supports enabled option" do
      opts = ValidateRequest.init(enabled: false)

      assert opts.enabled == false
    end
  end

  describe "call/2" do
    setup do
      {:ok, opts: ValidateRequest.init(schemas: %{test_action: CustomSchema})}
    end

    test "passes through when no schema for action", %{opts: opts} do
      conn =
        conn(:post, "/test")
        |> put_private(:phoenix_action, :unknown_action)
        |> ValidateRequest.call(opts)

      refute conn.halted
      refute conn.assigns[:bazaar_validated]
    end

    test "validates and stores data on valid request", %{opts: opts} do
      conn =
        conn(:post, "/test")
        |> put_private(:phoenix_action, :test_action)
        |> Map.put(:params, %{"name" => "Test", "amount" => "100"})
        |> ValidateRequest.call(opts)

      refute conn.halted
      assert conn.assigns[:bazaar_validated] == true
      assert conn.assigns[:bazaar_data].name == "Test"
      assert conn.assigns[:bazaar_data].amount == 100
    end

    test "halts and returns errors on invalid request", %{opts: opts} do
      conn =
        conn(:post, "/test")
        |> put_private(:phoenix_action, :test_action)
        |> Map.put(:params, %{"name" => "Test"})
        |> ValidateRequest.call(opts)

      assert conn.halted
      assert conn.status == 422

      body = JSON.decode!(conn.resp_body)
      assert body["error"] == "validation_error"
      assert is_list(body["details"])
    end

    test "skips validation when disabled", %{opts: _opts} do
      disabled_opts = ValidateRequest.init(enabled: false)

      conn =
        conn(:post, "/checkout-sessions")
        |> put_private(:phoenix_action, :create_checkout)
        |> Map.put(:params, %{})
        |> ValidateRequest.call(disabled_opts)

      refute conn.halted
      refute conn.assigns[:bazaar_validated]
    end
  end
end
