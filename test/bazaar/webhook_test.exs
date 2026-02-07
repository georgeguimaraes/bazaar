defmodule Bazaar.WebhookTest do
  use ExUnit.Case, async: true

  alias Bazaar.Webhook
  alias Bazaar.Webhook.Signature

  @order %{
    "id" => "order_123",
    "checkout_id" => "chk_456",
    "permalink_url" => "https://shop.example.com/orders/123",
    "line_items" => [],
    "totals" => []
  }

  @webhook_url "https://platform.example.com/webhooks/ucp"
  @webhook_secret "whsec_test_secret_123"

  describe "send/4" do
    test "sends signed webhook event to platform" do
      http_client = fn url, body, headers ->
        assert url == @webhook_url
        assert is_binary(body)

        # Verify payload structure
        payload = JSON.decode!(body)
        assert payload["event_type"] == "order_created"
        assert payload["order"]["id"] == "order_123"
        assert String.starts_with?(payload["event_id"], "evt_")

        # Verify signature header
        signature =
          Enum.find_value(headers, fn
            {"request-signature", sig} -> sig
            _ -> nil
          end)

        assert signature != nil
        assert Signature.verify(signature, payload, @webhook_secret) == :ok

        {:ok, %{status: 200, body: ""}}
      end

      assert {:ok, event} =
               Webhook.send(@order, :order_created, @webhook_url, @webhook_secret,
                 http_client: http_client
               )

      assert event["event_type"] == "order_created"
    end

    test "returns error on non-2xx response" do
      http_client = fn _url, _body, _headers ->
        {:ok, %{status: 500, body: "Internal Server Error"}}
      end

      assert {:error, {:http_error, 500, "Internal Server Error"}} =
               Webhook.send(@order, :order_created, @webhook_url, @webhook_secret,
                 http_client: http_client
               )
    end

    test "returns error on connection failure" do
      http_client = fn _url, _body, _headers ->
        {:error, :connection_refused}
      end

      assert {:error, :connection_refused} =
               Webhook.send(@order, :order_created, @webhook_url, @webhook_secret,
                 http_client: http_client
               )
    end

    test "supports all event types" do
      events_sent = :counters.new(1, [:atomics])

      http_client = fn _url, body, _headers ->
        payload = JSON.decode!(body)

        assert payload["event_type"] in [
                 "order_created",
                 "order_updated",
                 "fulfillment_updated",
                 "adjustment_created"
               ]

        :counters.add(events_sent, 1, 1)
        {:ok, %{status: 200, body: ""}}
      end

      for event_type <- [
            :order_created,
            :order_updated,
            :fulfillment_updated,
            :adjustment_created
          ] do
        assert {:ok, _} =
                 Webhook.send(@order, event_type, @webhook_url, @webhook_secret,
                   http_client: http_client
                 )
      end

      assert :counters.get(events_sent, 1) == 4
    end

    test "includes content-type header" do
      http_client = fn _url, _body, headers ->
        content_type =
          Enum.find_value(headers, fn
            {"content-type", ct} -> ct
            _ -> nil
          end)

        assert content_type == "application/json"
        {:ok, %{status: 200, body: ""}}
      end

      Webhook.send(@order, :order_created, @webhook_url, @webhook_secret,
        http_client: http_client
      )
    end
  end

  describe "sign_and_encode/2" do
    test "returns JSON body and signature header" do
      event = %{
        "event_id" => "evt_test",
        "event_type" => "order_created",
        "order" => @order
      }

      {body, signature} = Webhook.sign_and_encode(event, @webhook_secret)

      assert is_binary(body)
      assert JSON.decode!(body) == event
      assert Signature.verify(signature, event, @webhook_secret) == :ok
    end
  end
end
