defmodule Bazaar.Webhook do
  @moduledoc """
  Webhook client for sending events to platforms.

  This module handles building, signing, and sending webhook events
  to platforms when order-related events occur.

  ## Event Types

  - `:order_created` - New order has been placed
  - `:order_updated` - Order details have changed
  - `:fulfillment_updated` - Fulfillment status changed
  - `:adjustment_created` - Refund, credit, or chargeback issued

  ## HTTP Client

  This module doesn't include an HTTP client to avoid forcing dependencies.
  Pass an HTTP client function via the `:http_client` option:

      http_client = fn url, body, headers ->
        Req.post(url, body: body, headers: headers)
        |> case do
          {:ok, %{status: status, body: resp_body}} ->
            {:ok, %{status: status, body: resp_body}}
          {:error, reason} ->
            {:error, reason}
        end
      end

      Webhook.send(order, :order_created, webhook_url, webhook_secret,
        http_client: http_client)

  ## Telemetry

  Emits telemetry events under `[:bazaar, :webhook, :send]`:
  - `:start` - Before sending webhook
  - `:stop` - After successful send (includes `:event_type`, `:status`)
  - `:exception` - On error

  ## Example

      # When an order is created
      case Webhook.send(order, :order_created, platform_webhook_url, platform_secret,
             http_client: &my_http_post/3) do
        {:ok, event} -> Logger.info("Webhook sent: \#{event["event_id"]}")
        {:error, reason} -> Logger.error("Webhook failed: \#{inspect(reason)}")
      end
  """

  alias Bazaar.Telemetry
  alias Bazaar.Webhook.Signature
  alias Bazaar.WebhookEvent

  @doc """
  Sends a webhook event to a platform.

  Builds the event payload, signs it, and sends it to the webhook URL.

  ## Parameters

  - `order` - Order data map
  - `event_type` - One of the supported event types
  - `webhook_url` - Platform's webhook URL
  - `webhook_secret` - Shared secret for signing

  ## Options

  - `:http_client` - Required function `(url, body, headers) -> {:ok, %{status, body}} | {:error, reason}`

  ## Returns

  - `{:ok, event}` - Event payload that was sent
  - `{:error, {:http_error, status, body}}` - Non-2xx response
  - `{:error, reason}` - HTTP client error
  """
  def send(order, event_type, webhook_url, webhook_secret, opts \\ []) do
    http_client = Keyword.fetch!(opts, :http_client)

    Telemetry.span_with_metadata(
      [:bazaar, :webhook, :send],
      %{event_type: event_type},
      fn ->
        event = WebhookEvent.build(order, event_type)
        {body, signature} = sign_and_encode(event, webhook_secret)

        headers = [
          {"content-type", "application/json"},
          {Signature.header(), signature}
        ]

        case http_client.(webhook_url, body, headers) do
          {:ok, %{status: status}} when status >= 200 and status < 300 ->
            {{:ok, event}, %{status: status}}

          {:ok, %{status: status, body: resp_body}} ->
            {{:error, {:http_error, status, resp_body}}, %{status: status}}

          {:error, reason} ->
            {{:error, reason}, %{}}
        end
      end
    )
  end

  @doc """
  Signs an event and encodes it as JSON.

  Returns a tuple of `{json_body, signature}` ready for HTTP transport.

  ## Example

      {body, signature} = Webhook.sign_and_encode(event, secret)
      # body is JSON string
      # signature is detached JWT for request-signature header
  """
  def sign_and_encode(event, secret) when is_map(event) do
    body = JSON.encode!(event)
    signature = Signature.sign(event, secret)
    {body, signature}
  end
end
