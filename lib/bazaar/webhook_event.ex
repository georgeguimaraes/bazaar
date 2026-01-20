defmodule Bazaar.WebhookEvent do
  @moduledoc """
  Business logic helpers for UCP Webhook Events.

  Builds webhook event payloads for order-related notifications.

  ## Event Types

  - `:order_created` - New order has been placed
  - `:order_updated` - Order details have changed
  - `:fulfillment_updated` - Fulfillment status changed
  - `:adjustment_created` - Refund, credit, or chargeback issued

  ## Example

      event = Bazaar.WebhookEvent.build(order, :order_created)
      # => %{
      #   "event_id" => "evt_...",
      #   "event_type" => "order_created",
      #   "created_time" => "2026-01-19T...",
      #   "order" => order
      # }
  """

  @event_types [:order_created, :order_updated, :fulfillment_updated, :adjustment_created]

  @doc "Returns supported event types."
  def event_types, do: @event_types

  @doc """
  Builds a webhook event payload from an order and event type.

  Auto-generates `event_id` and `created_time` if not provided.

  ## Parameters

  - `order` - Order data map
  - `event_type` - One of: `:order_created`, `:order_updated`, `:fulfillment_updated`, `:adjustment_created`

  ## Returns

  A map with webhook event structure ready for sending.
  """
  def build(order, event_type) when event_type in @event_types do
    %{
      "event_id" => generate_event_id(),
      "event_type" => Atom.to_string(event_type),
      "created_time" => generate_timestamp(),
      "order" => order
    }
  end

  defp generate_event_id do
    "evt_" <> Base.encode16(:crypto.strong_rand_bytes(12), case: :lower)
  end

  defp generate_timestamp do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end
end
