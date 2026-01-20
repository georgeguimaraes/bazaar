# Schemas Guide

Bazaar schemas are **generated from official UCP JSON Schemas** using [Smelter](https://github.com/georgeguimaraes/smelter). They validate incoming data and provide type-safe access to fields.

## Architecture

Bazaar separates generated schemas from business logic:

```
lib/bazaar/
├── schemas/                    # Generated from JSON Schemas
│   ├── shopping/
│   │   ├── checkout_resp.ex    # Checkout validation
│   │   ├── order.ex            # Order validation
│   │   └── types/              # Shared types (line items, totals, etc.)
│   ├── capability/             # Capability definitions
│   └── ucp/                    # Discovery profile types
├── checkout.ex                 # Business logic: currency helpers
├── order.ex                    # Business logic: from_checkout helper
├── message.ex                  # Business logic: error/warning/info factories
└── fulfillment.ex              # Business logic: field definitions
```

**Generated schemas** provide `new/1` and `fields/0` functions.
**Business logic modules** add helpers and factories on top.

## Regenerating Schemas

When UCP JSON Schemas are updated, regenerate with:

```bash
mix bazaar.gen.schemas priv/ucp_schemas/2026-01-11
```

This will overwrite all files in `lib/bazaar/schemas/` with fresh generated code.

## Key Concepts

### Prices in Minor Units

UCP uses **minor currency units** (cents) as integers, not decimals:

```elixir
# $19.99 = 1999 cents
%{"price" => 1999}

# Convert dollars to cents
Bazaar.Checkout.to_minor_units(19.99)  # => 1999

# Convert cents to dollars
Bazaar.Checkout.to_major_units(1999)  # => 19.99
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

## Checkout Schema

The checkout schema validates shopping cart data. Use `Bazaar.Schemas.Shopping.CheckoutResp` for responses.

### Creating a Checkout

```elixir
params = %{
  "ucp" => %{"name" => "dev.ucp.shopping.checkout", "version" => "2026-01-11"},
  "id" => "checkout_123",
  "status" => "incomplete",
  "currency" => "USD",
  "line_items" => [
    %{
      "item" => %{"id" => "WIDGET-001", "title" => "Widget", "price" => 1999},
      "quantity" => 2,
      "totals" => [%{"type" => "subtotal", "amount" => 3998}]
    }
  ],
  "totals" => [%{"type" => "total", "amount" => 3998}],
  "links" => [%{"type" => "privacy_policy", "url" => "https://example.com/privacy"}],
  "payment" => %{}
}

case Bazaar.Schemas.Shopping.CheckoutResp.new(params) do
  %{valid?: true} = changeset ->
    checkout = Ecto.Changeset.apply_changes(changeset)
    # Process checkout...

  %{valid?: false} = changeset ->
    errors = Bazaar.Errors.from_changeset(changeset)
    # Handle validation errors...
end
```

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

## Order Schema

Use `Bazaar.Schemas.Shopping.Order` for order validation and `Bazaar.Order` for business logic.

### Creating from Checkout

```elixir
checkout = %{
  "id" => "checkout_abc",
  "currency" => "USD",
  "line_items" => [...],
  "totals" => [...]
}

order_params = Bazaar.Order.from_checkout(
  checkout,
  "order_123",
  "https://shop.example/orders/123"
)
# Returns a map ready to be validated with Bazaar.Schemas.Shopping.Order.new/1
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

Fulfillment event types: `shipped`, `out_for_delivery`, `delivered`, `failed`, `returned`

## Message Factories

Use `Bazaar.Message` to create error, warning, and info messages:

```elixir
# Create error message
error = Bazaar.Message.error(%{
  "code" => "out_of_stock",
  "content" => "Item SKU-123 is no longer available",
  "severity" => "recoverable",
  "path" => "$.line_items[0]"
})

# Create warning message
warning = Bazaar.Message.warning(%{
  "code" => "price_changed",
  "content" => "Price has increased since item was added"
})

# Create info message
info = Bazaar.Message.info(%{
  "code" => "promo_available",
  "content" => "Use code SAVE10 for 10% off"
})

# Parse message by type
changeset = Bazaar.Message.parse(%{"type" => "error", "code" => "...", ...})

# Validate list of messages
{:ok, messages} = Bazaar.Message.validate_messages([...])
```

### Severity Values

| Severity | Description |
|----------|-------------|
| `recoverable` | Agent can resolve automatically |
| `requires_buyer_input` | Need buyer action |
| `requires_buyer_review` | Need buyer confirmation |

## Discovery Profile

Use `Bazaar.DiscoveryProfile` to build the `/.well-known/ucp` response:

```elixir
profile = Bazaar.DiscoveryProfile.build(
  MyApp.UCPHandler,
  base_url: "https://api.mystore.com"
)
```

This is usually handled automatically by Bazaar's controller.

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
changeset = Bazaar.Schemas.Shopping.CheckoutResp.new(%{})

errors = Bazaar.Errors.from_changeset(changeset)
# => %{
#   "error" => "validation_error",
#   "message" => "Validation failed",
#   "details" => [
#     %{"field" => "currency", "message" => "can't be blank"},
#     %{"field" => "line_items", "message" => "can't be blank"},
#     ...
#   ]
# }
```

## Field Definitions

Access raw field definitions for custom use:

```elixir
# All checkout fields
Bazaar.Schemas.Shopping.CheckoutResp.fields()

# All order fields
Bazaar.Schemas.Shopping.Order.fields()

# Fulfillment configuration
Bazaar.Fulfillment.default_merchant_config()
Bazaar.Fulfillment.default_platform_config()
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

## Next Steps

- [Handlers Guide](handlers.md) - Use schemas in your handler
- [Plugs Guide](plugs.md) - Auto-validate requests
- [Testing Guide](testing.md) - Test schema validation
