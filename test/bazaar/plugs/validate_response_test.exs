defmodule Bazaar.Plugs.ValidateResponseTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  alias Bazaar.Plugs.ValidateResponse

  # Custom schema for testing
  defmodule CustomResponseSchema do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field(:id, :string)
      field(:status, :string)
    end

    def changeset(struct \\ %__MODULE__{}, params) do
      struct
      |> cast(params, [:id, :status])
      |> validate_required([:id, :status])
    end

    def new(params), do: changeset(params)
  end

  describe "init/1" do
    test "uses default schemas when none provided" do
      opts = ValidateResponse.init([])

      assert opts.schemas[:create_checkout] == Bazaar.Schemas.Shopping.CheckoutResp
      assert opts.schemas[:get_checkout] == Bazaar.Schemas.Shopping.CheckoutResp
      assert opts.schemas[:get_order] == Bazaar.Schemas.Shopping.Order
      assert opts.enabled == true
      assert opts.strict == false
    end

    test "merges custom schemas with defaults" do
      custom_schemas = %{create_checkout: CustomResponseSchema}
      opts = ValidateResponse.init(schemas: custom_schemas)

      assert opts.schemas[:create_checkout] == CustomResponseSchema
      assert opts.schemas[:get_checkout] == Bazaar.Schemas.Shopping.CheckoutResp
    end

    test "supports strict mode" do
      opts = ValidateResponse.init(strict: true)

      assert opts.strict == true
    end

    test "supports enabled option" do
      opts = ValidateResponse.init(enabled: false)

      assert opts.enabled == false
    end
  end

  describe "call/2" do
    setup do
      {:ok, opts: ValidateResponse.init(schemas: %{test_action: CustomResponseSchema})}
    end

    test "registers before_send callback", %{opts: opts} do
      conn =
        conn(:get, "/test")
        |> put_private(:phoenix_action, :test_action)
        |> ValidateResponse.call(opts)

      # The callback should be registered in private.before_send
      assert (conn.private[:before_send] || []) != []
    end

    test "does nothing when disabled" do
      opts = ValidateResponse.init(enabled: false)

      conn =
        conn(:get, "/test")
        |> put_private(:phoenix_action, :test_action)
        |> ValidateResponse.call(opts)

      # No callback registered
      assert conn.private[:before_send] == nil
    end
  end

  describe "validation behavior" do
    test "passes through valid responses" do
      opts =
        ValidateResponse.init(
          schemas: %{test_action: CustomResponseSchema},
          strict: true
        )

      conn =
        conn(:get, "/test")
        |> put_private(:phoenix_action, :test_action)
        |> ValidateResponse.call(opts)
        |> put_status(200)
        |> put_resp_content_type("application/json")
        |> resp(200, Jason.encode!(%{"id" => "123", "status" => "active"}))
        |> send_resp()

      assert conn.status == 200
    end

    test "raises in strict mode on invalid response" do
      opts =
        ValidateResponse.init(
          schemas: %{test_action: CustomResponseSchema},
          strict: true
        )

      assert_raise ValidateResponse.ValidationError, fn ->
        conn(:get, "/test")
        |> put_private(:phoenix_action, :test_action)
        |> ValidateResponse.call(opts)
        |> put_status(200)
        |> put_resp_content_type("application/json")
        |> resp(200, Jason.encode!(%{"invalid" => "data"}))
        |> send_resp()
      end
    end

    test "logs warning in non-strict mode on invalid response" do
      import ExUnit.CaptureLog

      opts =
        ValidateResponse.init(
          schemas: %{test_action: CustomResponseSchema},
          strict: false
        )

      log =
        capture_log(fn ->
          conn(:get, "/test")
          |> put_private(:phoenix_action, :test_action)
          |> ValidateResponse.call(opts)
          |> put_status(200)
          |> put_resp_content_type("application/json")
          |> resp(200, Jason.encode!(%{"invalid" => "data"}))
          |> send_resp()
        end)

      assert log =~ "Response validation failed"
      assert log =~ "test_action"
    end

    test "skips validation for non-2xx responses" do
      opts =
        ValidateResponse.init(
          schemas: %{test_action: CustomResponseSchema},
          strict: true
        )

      # Should not raise even though response is invalid
      conn =
        conn(:get, "/test")
        |> put_private(:phoenix_action, :test_action)
        |> ValidateResponse.call(opts)
        |> put_status(404)
        |> put_resp_content_type("application/json")
        |> resp(404, Jason.encode!(%{"error" => "not_found"}))
        |> send_resp()

      assert conn.status == 404
    end

    test "skips validation for actions without schema" do
      opts =
        ValidateResponse.init(
          schemas: %{test_action: CustomResponseSchema},
          strict: true
        )

      # unknown_action has no schema, should pass through
      conn =
        conn(:get, "/test")
        |> put_private(:phoenix_action, :unknown_action)
        |> ValidateResponse.call(opts)
        |> put_status(200)
        |> put_resp_content_type("application/json")
        |> resp(200, Jason.encode!(%{"anything" => "goes"}))
        |> send_resp()

      assert conn.status == 200
    end
  end
end
