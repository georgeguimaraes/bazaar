defmodule Bazaar.HandlerTest do
  use ExUnit.Case, async: true

  describe "use Bazaar.Handler" do
    test "provides default capabilities" do
      defmodule DefaultCapabilitiesHandler do
        use Bazaar.Handler
      end

      assert DefaultCapabilitiesHandler.capabilities() == [:checkout]
    end

    test "provides default business_profile" do
      defmodule DefaultProfileHandler do
        use Bazaar.Handler
      end

      profile = DefaultProfileHandler.business_profile()

      assert profile["name"] == "My Store"
      assert profile["description"] == "A UCP-enabled store"
    end

    test "allows overriding capabilities" do
      defmodule CustomCapabilitiesHandler do
        use Bazaar.Handler

        @impl true
        def capabilities, do: [:checkout, :orders, :identity]
      end

      assert CustomCapabilitiesHandler.capabilities() == [:checkout, :orders, :identity]
    end

    test "allows overriding business_profile" do
      defmodule CustomProfileHandler do
        use Bazaar.Handler

        @impl true
        def business_profile do
          %{
            "name" => "Custom Store",
            "description" => "A custom store",
            "website" => "https://custom.example.com"
          }
        end
      end

      profile = CustomProfileHandler.business_profile()

      assert profile["name"] == "Custom Store"
      assert profile["description"] == "A custom store"
      assert profile["website"] == "https://custom.example.com"
    end

    test "sets @behaviour attribute" do
      defmodule BehaviourCheckHandler do
        use Bazaar.Handler
      end

      # Check that the module has the behaviour attribute set
      behaviours = BehaviourCheckHandler.__info__(:attributes)[:behaviour] || []
      assert Bazaar.Handler in behaviours
    end
  end

  describe "checkout capability callbacks" do
    defmodule CheckoutHandler do
      use Bazaar.Handler

      @impl true
      def capabilities, do: [:checkout]

      @impl true
      def create_checkout(params, _conn) do
        {:ok, Map.put(params, "id", "checkout_123")}
      end

      @impl true
      def get_checkout("existing", _conn), do: {:ok, %{id: "existing", status: :open}}
      def get_checkout(_, _conn), do: {:error, :not_found}

      @impl true
      def update_checkout("existing", params, _conn) do
        {:ok, Map.merge(%{id: "existing"}, params)}
      end

      def update_checkout(_, _, _conn), do: {:error, :not_found}

      @impl true
      def cancel_checkout("existing", _conn), do: {:ok, %{id: "existing", status: :cancelled}}
      def cancel_checkout(_, _conn), do: {:error, :not_found}
    end

    test "create_checkout returns {:ok, checkout}" do
      result = CheckoutHandler.create_checkout(%{"currency" => "USD"}, nil)

      assert {:ok, checkout} = result
      assert checkout["id"] == "checkout_123"
      assert checkout["currency"] == "USD"
    end

    test "get_checkout returns {:ok, checkout} when found" do
      result = CheckoutHandler.get_checkout("existing", nil)

      assert {:ok, checkout} = result
      assert checkout.id == "existing"
    end

    test "get_checkout returns {:error, :not_found} when not found" do
      result = CheckoutHandler.get_checkout("nonexistent", nil)

      assert result == {:error, :not_found}
    end

    test "update_checkout returns {:ok, checkout} when found" do
      result = CheckoutHandler.update_checkout("existing", %{"total" => "99.99"}, nil)

      assert {:ok, checkout} = result
      assert checkout["total"] == "99.99"
    end

    test "update_checkout returns {:error, :not_found} when not found" do
      result = CheckoutHandler.update_checkout("nonexistent", %{}, nil)

      assert result == {:error, :not_found}
    end

    test "cancel_checkout returns {:ok, checkout} when found" do
      result = CheckoutHandler.cancel_checkout("existing", nil)

      assert {:ok, checkout} = result
      assert checkout.status == :cancelled
    end

    test "cancel_checkout returns {:error, :not_found} when not found" do
      result = CheckoutHandler.cancel_checkout("nonexistent", nil)

      assert result == {:error, :not_found}
    end
  end

  describe "orders capability callbacks" do
    defmodule OrdersHandler do
      use Bazaar.Handler

      @impl true
      def capabilities, do: [:orders]

      @impl true
      def get_order("order_123", _conn), do: {:ok, %{id: "order_123", status: :confirmed}}
      def get_order(_, _conn), do: {:error, :not_found}

      @impl true
      def cancel_order("order_123", _conn), do: {:ok, %{id: "order_123", status: :cancelled}}
      def cancel_order("shipped", _conn), do: {:error, :invalid_state}
      def cancel_order(_, _conn), do: {:error, :not_found}
    end

    test "get_order returns {:ok, order} when found" do
      result = OrdersHandler.get_order("order_123", nil)

      assert {:ok, order} = result
      assert order.id == "order_123"
      assert order.status == :confirmed
    end

    test "get_order returns {:error, :not_found} when not found" do
      result = OrdersHandler.get_order("nonexistent", nil)

      assert result == {:error, :not_found}
    end

    test "cancel_order returns {:ok, order} when found and cancellable" do
      result = OrdersHandler.cancel_order("order_123", nil)

      assert {:ok, order} = result
      assert order.status == :cancelled
    end

    test "cancel_order returns {:error, :invalid_state} when not cancellable" do
      result = OrdersHandler.cancel_order("shipped", nil)

      assert result == {:error, :invalid_state}
    end

    test "cancel_order returns {:error, :not_found} when not found" do
      result = OrdersHandler.cancel_order("nonexistent", nil)

      assert result == {:error, :not_found}
    end
  end

  describe "identity capability callbacks" do
    defmodule IdentityHandler do
      use Bazaar.Handler

      @impl true
      def capabilities, do: [:identity]

      @impl true
      def link_identity(%{"token" => token, "provider" => provider}, _conn) do
        {:ok, %{linked: true, provider: provider, token: token}}
      end

      def link_identity(%{"token" => _}, _conn), do: {:error, :missing_provider}
      def link_identity(_, _conn), do: {:error, :invalid_params}
    end

    test "link_identity returns {:ok, result} on success" do
      params = %{"token" => "abc123", "provider" => "google"}
      result = IdentityHandler.link_identity(params, nil)

      assert {:ok, data} = result
      assert data.linked == true
      assert data.provider == "google"
    end

    test "link_identity returns {:error, reason} on failure" do
      result = IdentityHandler.link_identity(%{"token" => "abc"}, nil)

      assert result == {:error, :missing_provider}
    end

    test "link_identity returns error for invalid params" do
      result = IdentityHandler.link_identity(%{}, nil)

      assert result == {:error, :invalid_params}
    end
  end

  describe "webhook callback" do
    defmodule WebhookHandler do
      use Bazaar.Handler

      @impl true
      def handle_webhook(%{"event" => "order.created", "data" => data}) do
        {:ok, %{processed: true, event: "order.created", data: data}}
      end

      def handle_webhook(%{"event" => "order.shipped", "data" => data}) do
        {:ok, %{processed: true, event: "order.shipped", data: data}}
      end

      def handle_webhook(%{"event" => _unknown}) do
        {:error, :unknown_event}
      end

      def handle_webhook(_) do
        {:error, :invalid_webhook}
      end
    end

    test "handle_webhook processes known events" do
      webhook = %{"event" => "order.created", "data" => %{"order_id" => "123"}}
      result = WebhookHandler.handle_webhook(webhook)

      assert {:ok, data} = result
      assert data.processed == true
      assert data.event == "order.created"
    end

    test "handle_webhook returns error for unknown events" do
      webhook = %{"event" => "unknown.event", "data" => %{}}
      result = WebhookHandler.handle_webhook(webhook)

      assert result == {:error, :unknown_event}
    end

    test "handle_webhook returns error for invalid format" do
      result = WebhookHandler.handle_webhook(%{})

      assert result == {:error, :invalid_webhook}
    end
  end

  describe "full handler implementation" do
    defmodule FullHandler do
      use Bazaar.Handler

      @impl true
      def capabilities, do: [:checkout, :orders, :identity]

      @impl true
      def business_profile do
        %{
          "name" => "Full Commerce Store",
          "description" => "A store with all capabilities",
          "support_email" => "support@example.com"
        }
      end

      @impl true
      def create_checkout(params, _conn), do: {:ok, params}

      @impl true
      def get_checkout(id, _conn), do: {:ok, %{id: id}}

      @impl true
      def update_checkout(id, params, _conn), do: {:ok, Map.put(params, :id, id)}

      @impl true
      def cancel_checkout(id, _conn), do: {:ok, %{id: id, status: :cancelled}}

      @impl true
      def get_order(id, _conn), do: {:ok, %{id: id}}

      @impl true
      def cancel_order(id, _conn), do: {:ok, %{id: id, status: :cancelled}}

      @impl true
      def link_identity(params, _conn), do: {:ok, params}

      @impl true
      def handle_webhook(params), do: {:ok, params}
    end

    test "has all capabilities" do
      assert FullHandler.capabilities() == [:checkout, :orders, :identity]
    end

    test "has custom business profile" do
      profile = FullHandler.business_profile()

      assert profile["name"] == "Full Commerce Store"
      assert profile["support_email"] == "support@example.com"
    end

    test "implements all checkout callbacks" do
      assert {:ok, _} = FullHandler.create_checkout(%{}, nil)
      assert {:ok, _} = FullHandler.get_checkout("id", nil)
      assert {:ok, _} = FullHandler.update_checkout("id", %{}, nil)
      assert {:ok, _} = FullHandler.cancel_checkout("id", nil)
    end

    test "implements all order callbacks" do
      assert {:ok, _} = FullHandler.get_order("id", nil)
      assert {:ok, _} = FullHandler.cancel_order("id", nil)
    end

    test "implements identity callback" do
      assert {:ok, _} = FullHandler.link_identity(%{}, nil)
    end

    test "implements webhook callback" do
      assert {:ok, _} = FullHandler.handle_webhook(%{})
    end
  end

  describe "handler with error responses" do
    defmodule ErrorHandler do
      use Bazaar.Handler

      @impl true
      def create_checkout(%{"invalid" => true}, _conn) do
        changeset = Bazaar.Schemas.CheckoutSession.new(%{})
        {:error, changeset}
      end

      def create_checkout(_, _conn), do: {:ok, %{}}

      @impl true
      def get_checkout(_, _conn), do: {:error, :not_found}

      @impl true
      def update_checkout(_, _, _conn), do: {:error, :invalid_state}

      @impl true
      def cancel_checkout(_, _conn), do: {:error, :already_cancelled}
    end

    test "can return changeset errors" do
      result = ErrorHandler.create_checkout(%{"invalid" => true}, nil)

      assert {:error, %Ecto.Changeset{}} = result
    end

    test "can return :not_found" do
      result = ErrorHandler.get_checkout("any", nil)

      assert result == {:error, :not_found}
    end

    test "can return :invalid_state" do
      result = ErrorHandler.update_checkout("id", %{}, nil)

      assert result == {:error, :invalid_state}
    end

    test "can return :already_cancelled" do
      result = ErrorHandler.cancel_checkout("id", nil)

      assert result == {:error, :already_cancelled}
    end
  end

  describe "minimal handler" do
    defmodule MinimalHandler do
      use Bazaar.Handler
      # Uses all defaults, doesn't implement any optional callbacks
    end

    test "compiles without implementing optional callbacks" do
      # This test passes if the module compiles
      assert MinimalHandler.capabilities() == [:checkout]
      assert is_map(MinimalHandler.business_profile())
    end
  end
end
