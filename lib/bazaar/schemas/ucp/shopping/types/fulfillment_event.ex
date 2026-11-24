defmodule Bazaar.Schemas.Shopping.Types.FulfillmentEvent do
  @moduledoc """
  Fulfillment Event

  Append-only fulfillment event representing an actual shipment. References line items by ID.

  Generated from: fulfillment_event.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @doc "Returns the description for a field, if available."
  def field_description(:carrier) do
    "Carrier name (e.g., 'FedEx', 'USPS')."
  end

  def field_description(:description) do
    "Human-readable description of the shipment status or delivery information (e.g., 'Delivered to front door', 'Out for delivery')."
  end

  def field_description(:id) do
    "Fulfillment event identifier."
  end

  def field_description(:line_items) do
    "Which line items and quantities are fulfilled in this event."
  end

  def field_description(:occurred_at) do
    "RFC 3339 timestamp when this fulfillment event occurred."
  end

  def field_description(:tracking_number) do
    "Carrier tracking number (required if type != processing)."
  end

  def field_description(:tracking_url) do
    "URL to track this shipment (required if type != processing)."
  end

  def field_description(:type) do
    "Fulfillment event type. Common values include: processing (preparing to ship), shipped (handed to carrier), in_transit (in delivery network), delivered (received by buyer), failed_attempt (delivery attempt failed), canceled (fulfillment canceled), undeliverable (cannot be delivered), returned_to_sender (returned to merchant)."
  end

  def field_description(field) when is_atom(field) do
    nil
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
