# Schemas Guide

Ucphi provides validated schemas for UCP data structures. These schemas validate incoming data and provide type-safe access to fields.

## Overview

Ucphi includes three main schemas:

| Schema | Purpose |
|--------|---------|
| `CheckoutSession` | Shopping cart / checkout data |
| `Order` | Completed order with fulfillment |
| `DiscoveryProfile` | Store capabilities manifest |

## CheckoutSession

The checkout session represents a shopping cart that can be converted into an order.

### Creating a Checkout

```elixir
params = %{
  "currency" => "USD",
  "line_items" => [
    %{
      "sku" => "WIDGET-001",
      "name" => "Amazing Widget",
      "quantity" => 2,
      "unit_price" => "29.99"
    }
  ]
}

case Ucphi.Schemas.CheckoutSession.new(params) do
  %{valid?: true} = changeset ->
    checkout = Ecto.Changeset.apply_changes(changeset)
    # checkout.currency => "USD"
    # checkout.line_items => [%{sku: "WIDGET-001", ...}]

  %{valid?: false} = changeset ->
    errors = Ucphi.Errors.from_changeset(changeset)
    # Handle validation errors
end
```

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `currency` | string | ISO 4217 code (USD, EUR, etc.) |
| `line_items` | array | At least one item required |

### Line Item Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `sku` | string | Yes | Product identifier |
| `quantity` | integer | Yes | Must be > 0 |
| `unit_price` | decimal | Yes | Price per unit |
| `name` | string | No | Display name |
| `description` | string | No | Item description |
| `image_url` | string | No | Product image URL |

### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `subtotal` | decimal | Sum before tax/shipping |
| `tax` | decimal | Tax amount |
| `shipping` | decimal | Shipping cost |
| `total` | decimal | Final total |
| `buyer` | object | Customer info |
| `shipping_address` | object | Delivery address |
| `billing_address` | object | Billing address |
| `metadata` | map | Custom key-value data |

### Buyer Fields

```elixir
%{
  "buyer" => %{
    "email" => "customer@example.com",
    "name" => "Jane Doe",
    "phone" => "+1-555-123-4567"
  }
}
```

### Address Fields

```elixir
%{
  "shipping_address" => %{
    "line1" => "123 Main Street",
    "line2" => "Apt 4B",
    "city" => "New York",
    "state" => "NY",
    "postal_code" => "10001",
    "country" => "US"
  }
}
```

### Complete Example

```elixir
params = %{
  "currency" => "USD",
  "line_items" => [
    %{
      "sku" => "LAPTOP-PRO",
      "name" => "Pro Laptop 15\"",
      "quantity" => 1,
      "unit_price" => "1299.00",
      "image_url" => "https://example.com/laptop.jpg"
    },
    %{
      "sku" => "CASE-001",
      "name" => "Laptop Case",
      "quantity" => 1,
      "unit_price" => "49.99"
    }
  ],
  "subtotal" => "1348.99",
  "tax" => "108.00",
  "shipping" => "0.00",
  "total" => "1456.99",
  "buyer" => %{
    "email" => "jane@example.com",
    "name" => "Jane Doe"
  },
  "shipping_address" => %{
    "line1" => "456 Oak Avenue",
    "city" => "San Francisco",
    "state" => "CA",
    "postal_code" => "94102",
    "country" => "US"
  },
  "metadata" => %{
    "source" => "mobile_app",
    "promo_code" => "SAVE10"
  }
}

changeset = Ucphi.Schemas.CheckoutSession.new(params)
```

### Updating a Checkout

```elixir
existing = %{
  id: "checkout_123",
  currency: "USD",
  status: :open,
  total: Decimal.new("100.00")
}

params = %{"total" => "150.00"}

changeset = Ucphi.Schemas.CheckoutSession.update(existing, params)
```

## Order

Orders represent completed checkouts with fulfillment tracking.

### Creating from Checkout

```elixir
checkout = %{
  id: "checkout_abc",
  currency: "USD",
  total: Decimal.new("99.99"),
  line_items: [...],
  buyer: %{...},
  shipping_address: %{...}
}

changeset = Ucphi.Schemas.Order.from_checkout(checkout, "order_123")
order = Ecto.Changeset.apply_changes(changeset)

# order.id => "order_123"
# order.checkout_session_id => "checkout_abc"
# order.status => :pending
# order.fulfillment_status => :unfulfilled
# order.payment_status => :pending
```

### Order Status Values

| Status | Description |
|--------|-------------|
| `:pending` | Order created, awaiting processing |
| `:confirmed` | Order confirmed |
| `:processing` | Being prepared |
| `:shipped` | In transit |
| `:delivered` | Delivered to customer |
| `:cancelled` | Order cancelled |
| `:refunded` | Payment refunded |

### Fulfillment Status Values

| Status | Description |
|--------|-------------|
| `:unfulfilled` | Not yet shipped |
| `:partially_fulfilled` | Some items shipped |
| `:fulfilled` | All items shipped |

### Payment Status Values

| Status | Description |
|--------|-------------|
| `:pending` | Awaiting payment |
| `:authorized` | Payment authorized |
| `:captured` | Payment captured |
| `:failed` | Payment failed |
| `:refunded` | Payment refunded |

### Shipments

Orders can have multiple shipments:

```elixir
%{
  "shipments" => [
    %{
      "id" => "ship_001",
      "carrier" => "UPS",
      "tracking_number" => "1Z999AA10123456784",
      "tracking_url" => "https://ups.com/track/1Z999AA10123456784",
      "status" => "in_transit"
    }
  ]
}
```

## DiscoveryProfile

The discovery profile describes your store for the `/.well-known/ucp` endpoint.

### Building from Handler

```elixir
changeset = Ucphi.Schemas.DiscoveryProfile.from_handler(
  MyApp.Commerce.Handler,
  base_url: "https://api.mystore.com"
)

profile = Ecto.Changeset.apply_changes(changeset)
```

### Manual Creation

```elixir
params = %{
  "name" => "My Store",
  "description" => "The best store ever",
  "logo_url" => "https://example.com/logo.png",
  "website" => "https://example.com",
  "support_email" => "support@example.com",
  "capabilities" => [
    %{"name" => "checkout", "version" => "1.0", "endpoint" => "/checkout-sessions"},
    %{"name" => "orders", "version" => "1.0", "endpoint" => "/orders"}
  ],
  "transports" => [
    %{"type" => "rest", "endpoint" => "https://api.example.com", "version" => "1.0"}
  ],
  "payment_handlers" => [
    %{"type" => "stripe", "enabled" => true}
  ],
  "metadata" => %{"region" => "us-east-1"}
}

changeset = Ucphi.Schemas.DiscoveryProfile.new(params)
```

## JSON Schema Generation

All schemas can generate JSON Schema for documentation:

```elixir
# Checkout schema
Ucphi.Schemas.CheckoutSession.json_schema()
# => %{"type" => "object", "properties" => %{...}}

# Order schema
Ucphi.Schemas.Order.json_schema()

# Discovery profile schema
Ucphi.Schemas.DiscoveryProfile.json_schema()
```

## Field Definitions

Access raw field definitions for custom use:

```elixir
# All checkout fields
Ucphi.Schemas.CheckoutSession.fields()

# Line item fields only
Ucphi.Schemas.CheckoutSession.line_item_fields()

# Address fields
Ucphi.Schemas.CheckoutSession.address_fields()

# Order shipment fields
Ucphi.Schemas.Order.shipment_fields()
```

## Currency Validation

Ucphi validates currencies against ISO 4217:

```elixir
Ucphi.Currencies.valid?("USD")  # => true
Ucphi.Currencies.valid?("EUR")  # => true
Ucphi.Currencies.valid?("XYZ")  # => false

# Get all supported currencies
Ucphi.Currencies.codes()
# => ["AED", "AFN", "ALL", ..., "ZWL"]
```

## Error Handling

Convert changeset errors to UCP format:

```elixir
changeset = Ucphi.Schemas.CheckoutSession.new(%{})

errors = Ucphi.Errors.from_changeset(changeset)
# => %{
#   "error" => "validation_error",
#   "message" => "Validation failed",
#   "details" => [
#     %{"field" => "currency", "message" => "can't be blank"},
#     %{"field" => "line_items", "message" => "can't be blank"}
#   ]
# }
```

## Tips

### Always Use String Keys

Schemas expect string keys in params:

```elixir
# Correct
%{"currency" => "USD"}

# Wrong - won't validate properly
%{currency: "USD"}
```

### Decimal Handling

Prices are cast to `Decimal`:

```elixir
changeset = Ucphi.Schemas.CheckoutSession.new(%{
  "currency" => "USD",
  "total" => "99.99",  # String is fine
  "line_items" => [...]
})

data = Ecto.Changeset.apply_changes(changeset)
data.total  # => #Decimal<99.99>
```

### Nested Validation

Line items and addresses are validated recursively:

```elixir
# This will fail - quantity must be > 0
params = %{
  "currency" => "USD",
  "line_items" => [
    %{"sku" => "ABC", "quantity" => 0, "unit_price" => "10.00"}
  ]
}

changeset = Ucphi.Schemas.CheckoutSession.new(params)
changeset.valid?  # => false
```

## Next Steps

- [Handlers Guide](handlers.md) - Use schemas in your handler
- [Plugs Guide](plugs.md) - Auto-validate requests
- [Testing Guide](testing.md) - Test schema validation
