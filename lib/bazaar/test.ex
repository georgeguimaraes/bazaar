if Code.ensure_loaded?(ExUnit.Assertions) do
  defmodule Bazaar.Test do
    @moduledoc """
    Helpers for testing a handler the way the platform reaches it.

        import Bazaar.Test

        test "prices roses" do
          {201, checkout} = request(MyApp.CommerceHandler, :create_checkout, checkout_request())
          assert_valid(checkout, :checkout)
          assert checkout["status"] == "ready_for_complete"
        end

    `request/4` drives `Bazaar.Phoenix.Controller` with the handler assigned,
    the way `bazaar_routes` does, and decodes the response. `assert_valid/2`
    validates a document with `Bazaar.Validator` (needs the `jsv` dependency)
    and fails with the validator's messages. `checkout_request/1` is a
    spec-shaped create body with one line item and a shipping method to a
    selected US destination, which `overrides` merge into.
    """

    import ExUnit.Assertions

    @doc "Asserts `document` validates as `schema` (a `Bazaar.Validator` schema name)."
    def assert_valid(document, schema) do
      case Bazaar.Validator.validate(document, schema) do
        {:ok, _} ->
          document

        {:error, %{details: details}} ->
          flunk("document is not a valid #{schema}:\n" <> Enum.join(leaf_messages(details), "\n"))

        {:error, other} ->
          flunk("document is not a valid #{schema}: #{inspect(other)}")
      end
    end

    @doc """
    Calls the controller `action` (`:create_checkout`, `:get_product`, ...)
    for `handler` with `params` and returns `{status, decoded_body}`. Path
    params (`"id"`) go in `params`. Options: `protocol: :acp`, `assigns:`.
    """
    def request(handler, action, params, opts \\ []) do
      method = if action in [:get_checkout, :get_cart, :get_order], do: :get, else: :post

      conn =
        Plug.Test.conn(method, "/", params)
        |> Plug.Conn.assign(:bazaar_handler, handler)
        |> Plug.Conn.assign(:bazaar_protocol, Keyword.get(opts, :protocol, :ucp))
        |> Plug.Conn.merge_assigns(Keyword.get(opts, :assigns, []))

      conn = apply(Bazaar.Phoenix.Controller, action, [conn, params])
      {conn.status, JSON.decode!(conn.resp_body)}
    end

    @doc "A checkout create request body in the spec's shape, with `overrides` merged in."
    def checkout_request(overrides \\ %{}) do
      Map.merge(
        %{
          "currency" => "USD",
          "line_items" => [%{"id" => "li_1", "item" => %{"id" => "sample"}, "quantity" => 1}],
          "buyer" => %{"email" => "buyer@example.com"},
          "fulfillment" => %{
            "methods" => [
              %{
                "id" => "m1",
                "type" => "shipping",
                "line_item_ids" => ["li_1"],
                "destinations" => [
                  %{"id" => "d1", "address_country" => "US", "postal_code" => "94105"}
                ],
                "selected_destination_id" => "d1"
              }
            ]
          }
        },
        overrides
      )
    end

    defp leaf_messages(details) do
      for %{instanceLocation: at, errors: errors} <- details,
          error <- errors,
          message <- leaves(at, error) do
        message
      end
    end

    defp leaves(_at, %{details: [_ | _] = nested}), do: leaf_messages(nested)
    defp leaves(at, %{message: message}), do: ["#{at}: #{message}"]
  end
end
