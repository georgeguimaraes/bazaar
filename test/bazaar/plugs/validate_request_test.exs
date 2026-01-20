defmodule Bazaar.Plugs.ValidateRequestTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  alias Bazaar.Plugs.ValidateRequest

  # Custom schema for testing
  defmodule CustomSchema do
    import Ecto.Changeset

    @fields [
      %{name: :name, type: :string},
      %{name: :amount, type: :integer}
    ]

    def new(params) do
      Schemecto.new(@fields, params)
      |> validate_required([:name, :amount])
      |> validate_number(:amount, greater_than: 0)
    end
  end

  describe "init/1" do
    test "uses default schemas when none provided" do
      opts = ValidateRequest.init([])

      assert opts[:create_checkout] == Bazaar.Schemas.Shopping.CheckoutResp
      assert opts[:update_checkout] == Bazaar.Schemas.Shopping.CheckoutResp
    end

    test "merges custom schemas with defaults" do
      custom_schemas = %{create_checkout: CustomSchema}
      opts = ValidateRequest.init(schemas: custom_schemas)

      assert opts[:create_checkout] == CustomSchema
      assert opts[:update_checkout] == Bazaar.Schemas.Shopping.CheckoutResp
    end

    test "allows adding new action schemas" do
      custom_schemas = %{custom_action: CustomSchema}
      opts = ValidateRequest.init(schemas: custom_schemas)

      assert opts[:custom_action] == CustomSchema
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

    test "validates with checkout schema", %{opts: _opts} do
      checkout_opts = ValidateRequest.init([])

      conn =
        conn(:post, "/checkout-sessions")
        |> put_private(:phoenix_action, :create_checkout)
        |> Map.put(:params, %{
          "ucp" => %{"name" => "dev.ucp.shopping.checkout", "version" => "2026-01-11"},
          "id" => "checkout_123",
          "status" => "incomplete",
          "currency" => "USD",
          "line_items" => [
            %{"item" => %{"id" => "PROD-1"}, "quantity" => 1}
          ],
          "totals" => [%{"type" => "total", "amount" => 1000}],
          "links" => [%{"type" => "privacy_policy", "url" => "https://example.com/privacy"}],
          "payment" => %{}
        })
        |> ValidateRequest.call(checkout_opts)

      refute conn.halted
      assert conn.assigns[:bazaar_validated] == true
      assert conn.assigns[:bazaar_data].currency == "USD"
    end

    test "rejects invalid checkout", %{opts: _opts} do
      checkout_opts = ValidateRequest.init([])

      conn =
        conn(:post, "/checkout-sessions")
        |> put_private(:phoenix_action, :create_checkout)
        |> Map.put(:params, %{"currency" => "INVALID"})
        |> ValidateRequest.call(checkout_opts)

      assert conn.halted
      assert conn.status == 422
    end
  end
end
