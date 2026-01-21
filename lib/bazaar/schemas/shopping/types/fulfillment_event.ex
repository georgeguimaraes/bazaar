defmodule Bazaar.Schemas.Shopping.Types.FulfillmentEvent do
  @moduledoc """
  Fulfillment Event
  
  Append-only fulfillment event representing an actual shipment. References line items by ID.
  
  Generated from: fulfillment_event.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    carrier: "Carrier name (e.g., 'FedEx', 'USPS').",
    description:
      "Human-readable description of the shipment status or delivery information (e.g., 'Delivered to front door', 'Out for delivery').",
    id: "Fulfillment event identifier.",
    line_items: "Which line items and quantities are fulfilled in this event.",
    occurred_at: "RFC 3339 timestamp when this fulfillment event occurred.",
    tracking_number: "Carrier tracking number (required if type != processing).",
    tracking_url: "URL to track this shipment (required if type != processing).",
    type:
      "Fulfillment event type. Common values include: processing (preparing to ship), shipped (handed to carrier), in_transit (in delivery network), delivered (received by buyer), failed_attempt (delivery attempt failed), canceled (fulfillment canceled), undeliverable (cannot be delivered), returned_to_sender (returned to merchant)."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:carrier, :string)
    field(:description, :string)
    field(:id, :string)
    field(:line_items, {:array, :map})
    field(:occurred_at, :utc_datetime)
    field(:tracking_number, :string)
    field(:tracking_url, :string)
    field(:type, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [
      :carrier,
      :description,
      :id,
      :line_items,
      :occurred_at,
      :tracking_number,
      :tracking_url,
      :type
    ])
    |> validate_required([:id, :occurred_at, :type, :line_items])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end