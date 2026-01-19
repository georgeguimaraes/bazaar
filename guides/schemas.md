# Schemas Guide

Bazaar provides validated schemas for UCP data structures. These schemas validate incoming data and provide type-safe access to fields.

## Overview

Bazaar includes these main schemas:

| Schema | Purpose |
|--------|---------|
| `CheckoutSession` | Shopping cart / checkout data |
| `Order` | Completed order with fulfillment |
| `DiscoveryProfile` | Store capabilities manifest |

## Key Concepts

### Prices in Minor Units

UCP uses **minor currency units** (cents) as integers, not decimals:

```elixir
# $19.99 = 1999 cents
%{"price" => 1999}

# Convert dollars to cents
Bazaar.Schemas.CheckoutSession.to_minor_units(19.99)  # => 1999

# Convert cents to dollars
Bazaar.Schemas.CheckoutSession.to_major_units(1999)  # => 19.99
```

### Structured Totals

Totals are arrays of typed amounts, not individual fields:

```elixir
"totals" => [
  %{"type" => "subtotal", "amount" => 3998},
  %{"type" => "tax", "amount" => 320},
  %{"type" => "fulfillment", "amount" => 500},
  %{"type" => "total", "amount" => 4818}
]
```

Total types: `items_discount`, `subtotal`, `discount`, `fulfillment`, `tax`, `fee`, `total`

### Required Links

Checkout responses require legal links:

```elixir
"links" => [
  %{"type" => "privacy_policy", "url" => "https://..."},
  %{"type" => "terms_of_service", "url" => "https://..."}
]
```

Link types: `privacy_policy`, `terms_of_service`, `refund_policy`, `shipping_policy`, `faq`

## CheckoutSession

The checkout session represents a shopping cart that can be converted into an order.

### Creating a Checkout (Request)

```elixir
params = %{
  "currency" => "USD",
  "line_items" => [
    %{
      "item" => %{"id" => "WIDGET-001"},
      "quantity" => 2
    }
  ],
  "payment" => %{}
}

case Bazaar.Schemas.CheckoutSession.new(params) do
  %{valid?: true} = changeset ->
    checkout = Ecto.Changeset.apply_changes(changeset)
    # Process checkout...

  %{valid?: false} = changeset ->
    errors = Bazaar.Errors.from_changeset(changeset)
    # Handle validation errors...
end
```

### Required Fields (Create Request)

| Field | Type | Description |
|-------|------|-------------|
| `currency` | string | ISO 4217 code (USD, EUR, etc.) |
| `line_items` | array | At least one item required |
| `payment` | object | Payment configuration |

### Line Item Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `item` | object | Yes | Item details (see below) |
| `quantity` | integer | Yes | Must be >= 1 |

### Item Fields (Request)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Product identifier |

### Item Fields (Response)

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Product identifier |
| `title` | string | Product title |
| `price` | integer | Unit price in cents |
| `image_url` | string | Product image URL |

### Checkout Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique checkout identifier |
| `status` | string | Status (see below) |
| `currency` | string | ISO 4217 currency code |
| `line_items` | array | Items with enriched data |
| `totals` | array | Typed total amounts |
| `links` | array | Required legal links |
| `payment` | object | Payment configuration |
| `buyer` | object | Customer info |
| `shipping_address` | object | Delivery address |
| `billing_address` | object | Billing address |
| `messages` | array | Error/warning/info messages |
| `continue_url` | string | URL for escalation handoff |
| `expires_at` | string | RFC 3339 expiry timestamp |
| `metadata` | map | Custom key-value data |

### Status Values

| Status | Description |
|--------|-------------|
| `incomplete` | Missing required info |
| `requires_escalation` | Needs browser handoff |
| `ready_for_complete` | Ready for payment |
| `complete_in_progress` | Payment processing |
| `completed` | Order created |
| `canceled` | Session cancelled |

### Buyer Fields

```elixir
%{
  "buyer" => %{
    "first_name" => "Jane",
    "last_name" => "Doe",
    "email" => "jane@example.com",
    "phone_number" => "+15551234567"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `first_name` | string | First name |
| `last_name` | string | Last name |
| `full_name` | string | Full name (if not using first/last) |
| `email` | string | Email address |
| `phone_number` | string | Phone in E.164 format |

### Address Fields

```elixir
%{
  "shipping_address" => %{
    "street_address" => "123 Main Street",
    "extended_address" => "Apt 4B",
    "address_locality" => "New York",
    "address_region" => "NY",
    "postal_code" => "10001",
    "address_country" => "US",
    "first_name" => "Jane",
    "last_name" => "Doe"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `street_address` | string | Street address |
| `extended_address` | string | Apartment, suite, etc. |
| `address_locality` | string | City |
| `address_region` | string | State/province (required for US/CA) |
| `postal_code` | string | Postal or ZIP code |
| `address_country` | string | ISO 3166-1 alpha-2 country code |
| `first_name` | string | Recipient first name |
| `last_name` | string | Recipient last name |
| `phone_number` | string | Contact phone number |

### Complete Checkout Response Example

```elixir
%{
  "id" => "checkout_abc123",
  "status" => "incomplete",
  "currency" => "USD",
  "line_items" => [
    %{
      "item" => %{
        "id" => "LAPTOP-PRO",
        "title" => "Pro Laptop 15\"",
        "price" => 129900,
        "image_url" => "https://example.com/laptop.jpg"
      },
      "quantity" => 1,
      "totals" => [
        %{"type" => "subtotal", "amount" => 129900}
      ]
    },
    %{
      "item" => %{
        "id" => "CASE-001",
        "title" => "Laptop Case",
        "price" => 4999
      },
      "quantity" => 1,
      "totals" => [
        %{"type" => "subtotal", "amount" => 4999}
      ]
    }
  ],
  "totals" => [
    %{"type" => "subtotal", "amount" => 134899},
    %{"type" => "tax", "amount" => 10800},
    %{"type" => "total", "amount" => 145699}
  ],
  "links" => [
    %{"type" => "privacy_policy", "url" => "https://example.com/privacy"},
    %{"type" => "terms_of_service", "url" => "https://example.com/terms"}
  ],
  "payment" => %{"handlers" => []},
  "buyer" => %{
    "first_name" => "Jane",
    "last_name" => "Doe",
    "email" => "jane@example.com"
  },
  "shipping_address" => %{
    "street_address" => "456 Oak Avenue",
    "address_locality" => "San Francisco",
    "address_region" => "CA",
    "postal_code" => "94102",
    "address_country" => "US"
  },
  "metadata" => %{
    "source" => "mobile_app",
    "promo_code" => "SAVE10"
  }
}
```

### Updating a Checkout

```elixir
existing = %{
  "id" => "checkout_123",
  "currency" => "USD",
  "status" => "incomplete"
}

params = %{
  "buyer" => %{"email" => "new@example.com"}
}

changeset = Bazaar.Schemas.CheckoutSession.update(existing, params)
```

## Order

Orders represent completed checkouts with fulfillment tracking.

### Creating from Checkout

```elixir
checkout = %{
  "id" => "checkout_abc",
  "currency" => "USD",
  "line_items" => [...],
  "totals" => [...]
}

changeset = Bazaar.Schemas.Order.from_checkout(
  checkout,
  "order_123",
  "https://shop.example/orders/123"
)
order = Ecto.Changeset.apply_changes(changeset)
```

### Order Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique order identifier |
| `checkout_id` | string | Associated checkout ID |
| `permalink_url` | string | URL to order on merchant site |
| `line_items` | array | Immutable line items |
| `totals` | array | Order totals |
| `fulfillment` | object | Expectations and events |
| `adjustments` | array | Refunds, credits, etc. |

### Fulfillment

```elixir
"fulfillment" => %{
  "expectations" => [
    %{
      "id" => "exp_1",
      "delivery_method" => "shipping",
      "estimated_delivery_date" => "2025-01-20T00:00:00Z",
      "line_item_ids" => ["li_1", "li_2"]
    }
  ],
  "events" => [
    %{
      "id" => "evt_1",
      "type" => "shipped",
      "timestamp" => "2025-01-15T14:30:00Z",
      "carrier" => "UPS",
      "tracking_number" => "1Z999AA10123456784",
      "tracking_url" => "https://ups.com/track/...",
      "line_item_ids" => ["li_1"]
    }
  ]
}
```

### Fulfillment Event Types

| Type | Description |
|------|-------------|
| `shipped` | Package shipped |
| `out_for_delivery` | Out for delivery |
| `delivered` | Package delivered |
| `failed` | Delivery failed |
| `returned` | Package returned |

### Adjustments

```elixir
"adjustments" => [
  %{
    "id" => "adj_1",
    "type" => "refund",
    "amount" => 1999,
    "reason" => "Customer requested",
    "timestamp" => "2025-01-16T10:00:00Z"
  }
]
```

Adjustment types: `refund`, `credit`, `chargeback`, `adjustment`

## DiscoveryProfile

The discovery profile describes your store for the `/.well-known/ucp` endpoint.

### Building from Handler

```elixir
changeset = Bazaar.Schemas.DiscoveryProfile.from_handler(
  MyApp.UCPHandler,
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
  ]
}

changeset = Bazaar.Schemas.DiscoveryProfile.new(params)
```

## JSON Schema Generation

All schemas can generate JSON Schema for documentation:

```elixir
# Checkout schema
Bazaar.Schemas.CheckoutSession.json_schema()
# => %{"type" => "object", "properties" => %{...}}

# Order schema
Bazaar.Schemas.Order.json_schema()

# Discovery profile schema
Bazaar.Schemas.DiscoveryProfile.json_schema()
```

## Validating Against Official UCP Schemas

Bazaar includes the official UCP JSON Schemas for conformance testing:

```elixir
# Validate a checkout response
{:ok, _} = Bazaar.Validator.validate_checkout(checkout_response)

# Validate an order response
{:ok, _} = Bazaar.Validator.validate_order(order_response)

# Get available schemas
Bazaar.Validator.available_schemas()  # => [:checkout, :order]
```

This is useful for testing that your handler returns valid UCP responses:

```elixir
test "checkout response matches UCP spec" do
  {:ok, checkout} = MyHandler.create_checkout(valid_params(), nil)
  assert {:ok, _} = Bazaar.Validator.validate_checkout(checkout)
end
```

## Field Definitions

Access raw field definitions for custom use:

```elixir
# All checkout fields
Bazaar.Schemas.CheckoutSession.fields()

# Line item fields
Bazaar.Schemas.CheckoutSession.line_item_fields()

# Buyer fields
Bazaar.Schemas.CheckoutSession.buyer_fields()

# Address fields
Bazaar.Schemas.CheckoutSession.address_fields()

# Total fields
Bazaar.Schemas.CheckoutSession.total_fields()

# Link fields
Bazaar.Schemas.CheckoutSession.link_fields()

# Order fulfillment fields
Bazaar.Schemas.Order.fulfillment_fields()
```

## Currency Validation

Bazaar validates currencies against ISO 4217:

```elixir
Bazaar.Currencies.valid?("USD")  # => true
Bazaar.Currencies.valid?("EUR")  # => true
Bazaar.Currencies.valid?("XYZ")  # => false

# Get all supported currencies
Bazaar.Currencies.codes()
# => ["AED", "AFN", "ALL", ..., "ZWL"]
```

## Error Handling

Convert changeset errors to UCP format:

```elixir
changeset = Bazaar.Schemas.CheckoutSession.new(%{})

errors = Bazaar.Errors.from_changeset(changeset)
# => %{
#   "error" => "validation_error",
#   "message" => "Validation failed",
#   "details" => [
#     %{"field" => "currency", "message" => "can't be blank"},
#     %{"field" => "line_items", "message" => "can't be blank"},
#     %{"field" => "payment", "message" => "can't be blank"}
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

### Integer Prices

Prices are integers in minor units (cents):

```elixir
# Correct - $19.99 as 1999 cents
%{"item" => %{"price" => 1999}}

# Wrong - decimal/string
%{"item" => %{"price" => "19.99"}}
```

### Nested Validation

Line items, totals, and addresses are validated recursively:

```elixir
# This will fail - quantity must be >= 1
params = %{
  "currency" => "USD",
  "line_items" => [
    %{"item" => %{"id" => "ABC"}, "quantity" => 0}
  ],
  "payment" => %{}
}

changeset = Bazaar.Schemas.CheckoutSession.new(params)
changeset.valid?  # => false
```

## Next Steps

- [Handlers Guide](handlers.md) - Use schemas in your handler
- [Plugs Guide](plugs.md) - Auto-validate requests
- [Testing Guide](testing.md) - Test schema validation
