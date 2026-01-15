defmodule Ucphi.Schemas.Order do
  @moduledoc """
  Schema for UCP Orders.

  An order represents a completed checkout session with payment
  and fulfillment information.
  """

  import Ecto.Changeset

  @status_values [:pending, :confirmed, :processing, :shipped, :delivered, :cancelled, :refunded]
  @fulfillment_status_values [:unfulfilled, :partially_fulfilled, :fulfilled]
  @payment_status_values [:pending, :authorized, :captured, :failed, :refunded]

  @status_type Ecto.ParameterizedType.init(Ecto.Enum, values: @status_values)
  @fulfillment_status_type Ecto.ParameterizedType.init(Ecto.Enum,
                             values: @fulfillment_status_values
                           )
  @payment_status_type Ecto.ParameterizedType.init(Ecto.Enum, values: @payment_status_values)

  @line_item_fields [
    %{name: :sku, type: :string, description: "Stock keeping unit identifier"},
    %{name: :name, type: :string, description: "Display name of the item"},
    %{name: :description, type: :string, description: "Item description"},
    %{name: :quantity, type: :integer, default: 1, description: "Quantity ordered"},
    %{name: :unit_price, type: :decimal, description: "Price per unit"},
    %{name: :image_url, type: :string, description: "URL to item image"}
  ]

  @buyer_fields [
    %{name: :email, type: :string, description: "Buyer email address"},
    %{name: :name, type: :string, description: "Buyer full name"},
    %{name: :phone, type: :string, description: "Buyer phone number"}
  ]

  @address_fields [
    %{name: :line1, type: :string, description: "Street address line 1"},
    %{name: :line2, type: :string, description: "Street address line 2"},
    %{name: :city, type: :string, description: "City"},
    %{name: :state, type: :string, description: "State or province"},
    %{name: :postal_code, type: :string, description: "Postal or ZIP code"},
    %{name: :country, type: :string, description: "ISO 3166-1 alpha-2 country code"}
  ]

  @shipment_fields [
    %{name: :id, type: :string, description: "Shipment identifier"},
    %{name: :carrier, type: :string, description: "Shipping carrier name"},
    %{name: :tracking_number, type: :string, description: "Tracking number"},
    %{name: :tracking_url, type: :string, description: "URL to track shipment"},
    %{name: :status, type: :string, description: "Shipment status"},
    %{name: :shipped_at, type: :utc_datetime},
    %{name: :delivered_at, type: :utc_datetime}
  ]

  @fields [
    %{name: :id, type: :string, description: "Unique order identifier"},
    %{name: :checkout_session_id, type: :string, description: "Original checkout session ID"},
    %{name: :status, type: @status_type},
    %{name: :fulfillment_status, type: @fulfillment_status_type},
    %{name: :payment_status, type: @payment_status_type},
    %{name: :currency, type: :string, description: "ISO 4217 currency code"},
    %{name: :subtotal, type: :decimal},
    %{name: :tax, type: :decimal},
    %{name: :shipping, type: :decimal},
    %{name: :total, type: :decimal},
    %{name: :line_items, type: Schemecto.many(@line_item_fields, with: &Function.identity/1)},
    %{name: :buyer, type: Schemecto.one(@buyer_fields, with: &Function.identity/1)},
    %{name: :shipping_address, type: Schemecto.one(@address_fields, with: &Function.identity/1)},
    %{name: :billing_address, type: Schemecto.one(@address_fields, with: &Function.identity/1)},
    %{name: :shipments, type: Schemecto.many(@shipment_fields, with: &Function.identity/1)},
    %{name: :metadata, type: :map, default: %{}},
    %{name: :created_at, type: :utc_datetime},
    %{name: :updated_at, type: :utc_datetime}
  ]

  @doc "Returns the field definitions for this schema."
  def fields, do: @fields

  @doc "Returns the shipment field definitions."
  def shipment_fields, do: @shipment_fields

  @doc "Creates a new order changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params)
    |> validate_required([:id, :status, :currency, :total, :line_items])
  end

  @doc "Creates an order from a completed checkout session."
  def from_checkout(checkout, order_id) do
    checkout
    |> Map.take([
      :currency,
      :subtotal,
      :tax,
      :shipping,
      :total,
      :line_items,
      :buyer,
      :shipping_address,
      :billing_address,
      :metadata
    ])
    |> Map.merge(%{
      id: order_id,
      checkout_session_id: checkout.id,
      status: :pending,
      fulfillment_status: :unfulfilled,
      payment_status: :pending,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    })
    |> new()
  end

  @doc "Generates JSON Schema for this type."
  def json_schema do
    # Filter out :utc_datetime fields as Schemecto doesn't support them in JSON Schema
    json_schema_fields =
      @fields
      |> Enum.reject(fn field -> field[:type] == :utc_datetime end)

    # Also filter datetime from shipment fields
    filtered_shipment_fields =
      @shipment_fields
      |> Enum.reject(fn field -> field[:type] == :utc_datetime end)

    # Replace shipments with filtered version
    json_schema_fields =
      Enum.map(json_schema_fields, fn
        %{name: :shipments} = field ->
          %{field | type: Schemecto.many(filtered_shipment_fields, with: &Function.identity/1)}

        field ->
          field
      end)

    Schemecto.new(json_schema_fields) |> Schemecto.to_json_schema()
  end
end
