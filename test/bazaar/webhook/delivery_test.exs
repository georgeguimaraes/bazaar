defmodule Bazaar.Webhook.DeliveryTest do
  use ExUnit.Case, async: true

  alias Bazaar.Webhook.Delivery

  describe "deliver/4 with default strategy" do
    test "returns {:ok, event} on successful delivery" do
      http_client = fn _url, _body, _headers ->
        {:ok, %{status: 200, body: ""}}
      end

      order = %{"id" => "ord_123", "status" => "completed"}

      result =
        Delivery.deliver(
          order,
          :order_created,
          "https://example.com/webhooks",
          "secret123",
          http_client: http_client
        )

      assert {:ok, event} = result
      assert event["event_type"] == "order_created"
      assert event["order"] == order
    end

    test "retries on retryable errors" do
      # Track call count using process dictionary
      agent = start_supervised!({Agent, fn -> 0 end})

      http_client = fn _url, _body, _headers ->
        count = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

        if count < 2 do
          {:ok, %{status: 500, body: "Server Error"}}
        else
          {:ok, %{status: 200, body: ""}}
        end
      end

      order = %{"id" => "ord_123"}

      result =
        Delivery.deliver(
          order,
          :order_created,
          "https://example.com/webhooks",
          "secret",
          http_client: http_client,
          max_attempts: 5,
          base_delay: 10
        )

      assert {:ok, _event} = result
      assert Agent.get(agent, & &1) == 3
    end

    test "returns error after max attempts" do
      http_client = fn _url, _body, _headers ->
        {:ok, %{status: 500, body: "Server Error"}}
      end

      order = %{"id" => "ord_123"}

      result =
        Delivery.deliver(
          order,
          :order_created,
          "https://example.com/webhooks",
          "secret",
          http_client: http_client,
          max_attempts: 3,
          base_delay: 1
        )

      assert {:error, {:max_attempts_reached, 3, {:http_error, 500, "Server Error"}}} = result
    end

    test "does not retry non-retryable errors" do
      agent = start_supervised!({Agent, fn -> 0 end})

      http_client = fn _url, _body, _headers ->
        Agent.update(agent, &(&1 + 1))
        {:ok, %{status: 400, body: "Bad Request"}}
      end

      order = %{"id" => "ord_123"}

      result =
        Delivery.deliver(
          order,
          :order_created,
          "https://example.com/webhooks",
          "secret",
          http_client: http_client,
          max_attempts: 5
        )

      assert {:error, {:http_error, 400, "Bad Request"}} = result
      assert Agent.get(agent, & &1) == 1
    end

    test "supports custom retry options" do
      agent = start_supervised!({Agent, fn -> [] end})

      http_client = fn _url, _body, _headers ->
        Agent.update(agent, fn times -> [System.monotonic_time(:millisecond) | times] end)
        {:ok, %{status: 503, body: ""}}
      end

      order = %{"id" => "ord_123"}

      _result =
        Delivery.deliver(
          order,
          :order_created,
          "https://example.com/webhooks",
          "secret",
          http_client: http_client,
          max_attempts: 3,
          base_delay: 50
        )

      times = Agent.get(agent, & &1) |> Enum.reverse()
      assert length(times) == 3
    end
  end

  describe "Delivery behaviour" do
    defmodule TestDelivery do
      @behaviour Bazaar.Webhook.Delivery

      @impl true
      def deliver(_order, event_type, _url, _secret, opts) do
        send(opts[:test_pid], {:delivered, event_type})
        {:ok, %{"event_type" => to_string(event_type)}}
      end
    end

    test "custom delivery module can be used" do
      result = TestDelivery.deliver(%{}, :order_created, "url", "secret", test_pid: self())

      assert {:ok, %{"event_type" => "order_created"}} = result
      assert_receive {:delivered, :order_created}
    end
  end
end
