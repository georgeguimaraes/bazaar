defmodule Bazaar.Schemas.Shopping.Types.FulfillmentEvent do
  @moduledoc """
  Fulfillment Event
  
  Append-only fulfillment event representing an actual shipment. References line items by ID.
  
  Generated from: fulfillment_event.json
  """
  import Ecto.Changeset

  @fields [
    %{name: :carrier, type: :string, description: "Carrier name (e.g., 'FedEx', 'USPS')."},
    %{
      name: :description,
      type: :string,
      description:
        "Human-readable description of the shipment status or delivery information (e.g., 'Delivered to front door', 'Out for delivery')."
    },
    %{name: :id, type: :string, description: "Fulfillment event identifier."},
    %{
      name: :line_items,
      type: {:array, :map},
      description: "Which line items and quantities are fulfilled in this event."
    },
    %{
      name: :occurred_at,
      type: :utc_datetime,
      description: "RFC 3339 timestamp when this fulfillment event occurred."
    },
    %{
      name: :tracking_number,
      type: :string,
      description: "Carrier tracking number (required if type != processing)."
    },
    %{
      name: :tracking_url,
      type: :string,
      description: "URL to track this shipment (required if type != processing)."
    },
    %{
      name: :type,
      type: :string,
      description:
        "Fulfillment event type. Common values include: processing (preparing to ship), shipped (handed to carrier), in_transit (in delivery network), delivered (received by buyer), failed_attempt (delivery attempt failed), canceled (fulfillment canceled), undeliverable (cannot be delivered), returned_to_sender (returned to merchant)."
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:id, :occurred_at, :type, :line_items])
  end
end