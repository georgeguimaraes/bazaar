defmodule Bazaar.Schemas.Order do
  @moduledoc """
  Schema for UCP Orders.

  An order represents a completed checkout session with payment
  and fulfillment information.

  ## Spec Compliance

  This schema follows the official UCP specification:
  - Prices are in **minor units** (cents) as integers
  - Includes `checkout_id` for reconciliation
  - Requires `permalink_url` for order access
  - Fulfillment with expectations and events
  - Adjustments for refunds and money movements
  """

  import Ecto.Changeset

  # Reuse types from CheckoutSession
  alias Bazaar.Schemas.CheckoutSession

  # Adjustment type values per UCP spec
  @adjustment_type_values [:refund, :credit, :chargeback, :adjustment]
  @adjustment_type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @adjustment_type_values)

  # Fulfillment event type values
  @fulfillment_event_type_values [:shipped, :out_for_delivery, :delivered, :failed, :returned]
  @fulfillment_event_type_type Ecto.ParameterizedType.init(Ecto.Enum,
                                 values: @fulfillment_event_type_values
                               )

  # UCP response wrapper
  @ucp_fields [
    %{name: :name, type: :string, description: "Capability name in reverse-domain notation"},
    %{name: :version, type: :string, description: "Protocol version (YYYY-MM-DD format)"}
  ]

  # Item response fields (immutable in orders)
  @order_line_item_fields [
    %{
      name: :item,
      type: Schemecto.one(CheckoutSession.line_item_response_fields(), with: &Function.identity/1)
    },
    %{name: :quantity, type: :integer, description: "Quantity ordered"}
  ]

  # Fulfillment expectation (buyer-facing delivery groups)
  @expectation_fields [
    %{name: :id, type: :string, description: "Expectation identifier"},
    %{
      name: :delivery_method,
      type: :string,
      description: "Delivery method (shipping, pickup, etc.)"
    },
    %{
      name: :estimated_delivery_date,
      type: :string,
      description: "Estimated delivery date (RFC 3339)"
    },
    %{
      name: :line_item_ids,
      type: {:array, :string},
      description: "Line items in this fulfillment group"
    }
  ]

  # Fulfillment event (actual shipment events)
  @fulfillment_event_fields [
    %{name: :id, type: :string, description: "Event identifier"},
    %{name: :type, type: @fulfillment_event_type_type, description: "Event type"},
    %{name: :timestamp, type: :string, description: "Event timestamp (RFC 3339)"},
    %{name: :carrier, type: :string, description: "Shipping carrier name"},
    %{name: :tracking_number, type: :string, description: "Tracking number"},
    %{name: :tracking_url, type: :string, description: "URL to track shipment"},
    %{name: :line_item_ids, type: {:array, :string}, description: "Line items in this shipment"}
  ]

  # Fulfillment object
  @fulfillment_fields [
    %{
      name: :expectations,
      type: Schemecto.many(@expectation_fields, with: &Function.identity/1),
      description: "Buyer-facing groups for when/how items will be delivered"
    },
    %{
      name: :events,
      type: Schemecto.many(@fulfillment_event_fields, with: &Function.identity/1),
      description: "Append-only event log of actual shipments"
    }
  ]

  # Adjustment (refunds, credits, chargebacks)
  @adjustment_fields [
    %{name: :id, type: :string, description: "Adjustment identifier"},
    %{name: :type, type: @adjustment_type_type, description: "Type of adjustment"},
    %{name: :amount, type: :integer, description: "Amount in minor currency units (cents)"},
    %{name: :reason, type: :string, description: "Reason for adjustment"},
    %{name: :timestamp, type: :string, description: "Adjustment timestamp (RFC 3339)"}
  ]

  @fields [
    %{
      name: :ucp,
      type: Schemecto.one(@ucp_fields, with: &Function.identity/1),
      description: "UCP response metadata"
    },
    %{name: :id, type: :string, description: "Unique order identifier"},
    %{
      name: :checkout_id,
      type: :string,
      description: "Associated checkout ID for reconciliation"
    },
    %{
      name: :permalink_url,
      type: :string,
      description: "Permalink to access the order on merchant site"
    },
    %{name: :currency, type: :string, description: "ISO 4217 currency code"},
    %{
      name: :line_items,
      type: Schemecto.many(@order_line_item_fields, with: &Function.identity/1),
      description: "Immutable line items (source of truth for what was ordered)"
    },
    %{
      name: :fulfillment,
      type: Schemecto.one(@fulfillment_fields, with: &Function.identity/1),
      description: "Fulfillment data with expectations and events"
    },
    %{
      name: :adjustments,
      type: Schemecto.many(@adjustment_fields, with: &__MODULE__.validate_adjustment/1),
      description: "Append-only event log of money movements (refunds, etc.)"
    },
    %{
      name: :totals,
      type:
        Schemecto.many(CheckoutSession.total_fields(), with: &CheckoutSession.validate_total/1),
      description: "Different totals for the order"
    },
    %{name: :metadata, type: :map, default: %{}, description: "Custom key-value data"},
    %{name: :created_at, type: :utc_datetime},
    %{name: :updated_at, type: :utc_datetime}
  ]

  @doc "Returns the field definitions for this schema."
  def fields, do: @fields

  @doc "Returns the fulfillment field definitions."
  def fulfillment_fields, do: @fulfillment_fields

  @doc "Returns the expectation field definitions."
  def expectation_fields, do: @expectation_fields

  @doc "Returns the fulfillment event field definitions."
  def fulfillment_event_fields, do: @fulfillment_event_fields

  @doc "Returns the adjustment field definitions."
  def adjustment_fields, do: @adjustment_fields

  @doc "Returns the adjustment type values."
  def adjustment_type_values, do: @adjustment_type_values

  @doc "Returns the fulfillment event type values."
  def fulfillment_event_type_values, do: @fulfillment_event_type_values

  @doc """
  Creates a new order changeset from params.

  ## Required Fields

  - `id` - Unique order identifier
  - `checkout_id` - Associated checkout session ID
  - `permalink_url` - URL to access order on merchant site
  - `line_items` - Immutable line items from checkout
  - `totals` - Order totals
  """
  def new(params \\ %{}) do
    Schemecto.new(@fields, params)
    |> validate_required([:id, :checkout_id, :permalink_url, :line_items, :totals])
    |> validate_format(:permalink_url, ~r/^https?:\/\//, message: "must be a valid URL")
  end

  @doc "Validates an adjustment changeset."
  def validate_adjustment(changeset) do
    changeset
    |> validate_required([:id, :type, :amount])
    |> validate_number(:amount, greater_than_or_equal_to: 0)
  end

  @doc """
  Creates an order from a completed checkout session.

  ## Example

      order = Bazaar.Schemas.Order.from_checkout(checkout_data, "order-123", "https://shop.com/orders/123")
  """
  def from_checkout(checkout, order_id, permalink_url) do
    %{
      "id" => order_id,
      "checkout_id" => checkout[:id] || checkout["id"],
      "permalink_url" => permalink_url,
      "currency" => checkout[:currency] || checkout["currency"],
      "line_items" => checkout[:line_items] || checkout["line_items"] || [],
      "totals" => checkout[:totals] || checkout["totals"] || [],
      "fulfillment" => %{
        "expectations" => [],
        "events" => []
      },
      "adjustments" => [],
      "ucp" => %{
        "name" => "dev.ucp.shopping.order",
        "version" => "2026-01-11"
      }
    }
    |> new()
  end

  @doc "Generates JSON Schema for this type."
  def json_schema do
    json_schema_fields =
      @fields
      |> Enum.reject(fn field -> field[:type] == :utc_datetime end)

    Schemecto.new(json_schema_fields) |> Schemecto.to_json_schema()
  end
end
