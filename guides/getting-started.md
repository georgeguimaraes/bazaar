# Getting Started

From an empty Phoenix app to a store an agent can discover, browse and buy from, in a few minutes. The generator writes a handler that answers on first boot; then you swap its placeholder data for yours.

## Prerequisites

- Elixir 1.18 or later
- Phoenix 1.7 or later

## 1. A Phoenix app

```bash
mix phx.new my_store --no-html --no-assets --no-mailer
cd my_store
```

An existing app works the same way.

## 2. Add bazaar

In `mix.exs`:

```elixir
defp deps do
  [
    {:bazaar, "~> 0.4"},
    # optional: validates your responses against the spec's JSON Schemas in dev and test
    {:jsv, "~> 0.15"}
  ]
end
```

```bash
mix deps.get
```

## 3. Generate the handler

```bash
mix bazaar.gen.handler MyStore.CommerceHandler --name "My Store"
```

This writes `lib/my_store/commerce_handler.ex` and `lib/my_store/shop.ex`, and prints the wiring below. The default capabilities are checkout, orders and fulfillment; add `--capabilities checkout,orders,fulfillment,discount,cart,catalog` for everything the scaffold generates (location, loyalty and payment terms are opt-in beyond it, see the handlers guide).

The handler is three lines: `use Bazaar.Handler, shop: MyStore.Shop, store: Bazaar.Store.ETS` plus the capabilities and the business profile. Every callback comes from the library's defaults over the shop. The shop is a `Bazaar.Shop` with placeholders (a sample product, one flat shipping rate), so the app works before you have written any commerce code; `Bazaar.Store.ETS` keeps checkouts and orders in memory until you move them to your database.

## 4. Wire it in

The generator prints these four steps for your module names.

Read the raw body in your endpoint, which signature verification needs (`lib/my_store_web/endpoint.ex`):

```elixir
plug Plug.Parsers,
  parsers: [:json],
  pass: ["*/*"],
  json_decoder: Jason,
  body_reader: {Bazaar.Plugs.RawBody, :read_body, []}
```

Mount the routes (`lib/my_store_web/router.ex`):

```elixir
use Bazaar.Phoenix.Router

pipeline :ucp do
  plug :accepts, ["json"]
  plug Bazaar.Plugs.UCP
end

scope "/" do
  pipe_through :ucp
  bazaar_routes "/", MyStore.CommerceHandler
end
```

`Bazaar.Plugs.UCP` negotiates the spec version from the `UCP-Agent` header and replays idempotent requests. Add `Bazaar.Plugs.VerifySignature` once you talk to a platform that signs its requests, and `Bazaar.Plugs.ValidateResponse, strict: true` in dev and test to have every response checked against the spec. The [plugs guide](plugs.md) has the details.

Start the store and the idempotency table (`lib/my_store/application.ex`):

```elixir
children = [
  Bazaar.Store.ETS,
  Bazaar.Idempotency.ETS,
  MyStoreWeb.Endpoint
]
```

Tell the handler where it lives (`config/runtime.exs`):

```elixir
config :my_store, bazaar_base_url: System.get_env("BASE_URL", "http://localhost:4000")
```

## 5. Try it

```bash
mix phx.server
```

```bash
curl localhost:4000/.well-known/ucp
```

That is the discovery profile: the spec version, the capabilities and the endpoint an agent will use. Then a checkout for the sample product:

```bash
curl -X POST localhost:4000/checkout-sessions \
  -H 'content-type: application/json' \
  -d '{"currency":"USD","line_items":[{"item":{"id":"sample"},"quantity":2}]}'
```

The response is a full checkout document: the line priced from `products/0`, totals, links, status `ready_for_complete`. Send a fulfillment method with a destination in an update and the flat rate shows up as an option; select it and complete, and an order appears under `/orders/:id`.

## 6. Make it yours

Everything to replace is in `lib/my_store/shop.ex`, one function per fact:

| Function | What it answers |
|---|---|
| `products/0` | your catalog in the spec's shape (variants are what gets bought) |
| `item/1` | a line item's title, price and stock |
| `fulfillment_options/2` | shipping or pickup options for a destination, with the priced line items and subtotal in hand |
| `discount/2` | what a code is worth on the running total |
| `stored_addresses/1` | addresses you know for a returning buyer |
| `authorize/1` | charging the instruments through your payment provider |
| `payment_handlers/0` and the handler's `business_profile/0` | the payment handlers you accept |
| `order_placed/2` | telling the platform about the order with `Bazaar.Webhook.deliver/2` |

Then implement `Bazaar.Store` on your database and pass it as `store:`. The [handlers guide](handlers.md) has every callback, what the defaults do, and how to override one.

If you would rather own the routes and controllers, skip `bazaar_routes`: build the discovery document with `Bazaar.DiscoveryProfile.from_handler/2`, call the callbacks from your own actions, and keep the plugs and builders.

## Where next

- [Handlers](handlers.md): every callback and the documents they return
- [Plugs](plugs.md): version negotiation, idempotency, signatures, validation
- [examples/flower_shop](https://github.com/georgeguimaraes/bazaar/tree/main/examples/flower_shop): a complete store that passes the official UCP conformance suite
