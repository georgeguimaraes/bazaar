# Handlers

A bazaar store is three modules: a `Bazaar.Shop` with your facts (prices, stock, rates, stores), a `Bazaar.Store` with your persistence, and a `Bazaar.Handler` that names them and declares what the store offers. The handler's callbacks all have defaults; you override one when a default doesn't fit.

```elixir
defmodule MyApp.CommerceHandler do
  use Bazaar.Handler, shop: MyApp.Shop, store: Bazaar.Store.ETS

  @impl true
  def capabilities, do: [:checkout, :orders, :fulfillment]

  @impl true
  def business_profile do
    %{"name" => "My Store", "description" => "What we sell"}
  end
end
```

`mix bazaar.gen.handler MyApp.CommerceHandler` writes this module and a shop with placeholder data (see the [getting started guide](getting-started.md)).

## Internal format: UCP

Handlers speak UCP. On ACP routes the controller translates requests before and responses after, so the same shop and handler serve both.

## The shop

`Bazaar.Shop` is a behaviour with two required callbacks and defaults for the rest from `use Bazaar.Shop`. Every callback is pure and takes exactly what the library's builders document.

| Callback | Answers | Default |
|---|---|---|
| `base_url/0` | where the store lives, for order permalinks and cart links | required |
| `item/1` | a line item's `title`, `price` and `stock` (`nil` unlimited), `nil` when unknown | required |
| `fulfillment_options/2` | options for a selected destination (`context` has the priced line items and subtotal) | none |
| `pickup_locations/1` | stores a pickup method can be fulfilled at (`id`, `name`, `address`) | no pickup |
| `stored_addresses/1` | addresses known for a buyer, injected into methods that carry none | none |
| `discount/2` | what a code is worth on the running total | no discounts |
| `payment_handlers/0` | the `ucp.payment_handlers` registry on checkouts | `%{}` |
| `links/0` | the legal links on checkouts | privacy and terms under `base_url/0` |
| `loyalty/1` | memberships answering `context.eligibility` claims | none |
| `payment_terms/1` | selectable payment terms for a total | immediate only |
| `authorize/1` | charging the instruments at completion | an instrument is required |
| `order_placed/2` | called with the order and the conn once placed | nothing |
| `products/0` | the catalog | `[]` |
| `locations/0` | the stores | `[]` |
| `serves?/2`, `stocks?/2` | location search predicates | unsupported (such requests are rejected, as the spec asks) |

```elixir
defmodule MyApp.Shop do
  use Bazaar.Shop

  @impl true
  def base_url, do: MyAppWeb.Endpoint.url()

  @impl true
  def item(id) do
    case MyApp.Products.get(id) do
      nil -> nil
      product -> %{item: %{"title" => product.name, "price" => product.price_cents}, stock: product.stock}
    end
  end

  @impl true
  def fulfillment_options(%{"address_country" => country}, %{subtotal: subtotal}) do
    for rate <- MyApp.Shipping.rates(country, subtotal) do
      %{"id" => rate.id, "title" => rate.title, "totals" => [%{"type" => "total", "amount" => rate.cents}]}
    end
  end

  @impl true
  def authorize(instruments), do: MyApp.Payments.charge(instruments)
end
```

Everything protocol-shaped happens in the library on top of these: pricing lines and clamping to stock, totals in the spec's order, discount allocations, fulfillment carry-over between updates, pickup at your locations, status, the `ucp` envelope. `Bazaar.Checkout`, `Bazaar.Cart`, `Bazaar.Catalog` and `Bazaar.Location` document the rules.

## The store

`Bazaar.Store` is nine functions over checkouts (states), carts (states), orders (documents) and the cart-to-checkout index. `Bazaar.Store.ETS` is the in-memory one: add it to your supervision tree next to `Bazaar.Idempotency.ETS`. For production, implement the behaviour on your database:

```elixir
defmodule MyApp.CommerceStore do
  @behaviour Bazaar.Store

  @impl true
  def get_checkout(id), do: MyApp.Repo.get(MyApp.CheckoutState, id) |> to_state()

  @impl true
  def put_checkout(state) do
    MyApp.Repo.insert!(from_state(state), on_conflict: :replace_all, conflict_target: :id)
    state
  end

  # ... get_cart/1, put_cart/1, delete_cart/1, get_order/1, put_order/1,
  #     checkout_for_cart/1, put_checkout_for_cart/2
end
```

States are plain maps with atom keys, documented on `Bazaar.Checkout`; storing them as JSON or a map column works.

## What the defaults do

With `shop:` and `store:` given, `use Bazaar.Handler` defines every capability's callbacks from `Bazaar.Handler.Defaults`:

- **Checkout**: create (or convert the cart named by `cart_id`, once), get, update while open, cancel, and complete: apply the final update, refuse with a `missing` message until fulfillment is selected (when `:fulfillment` is advertised) and no error remains, then `authorize/1`, `Bazaar.Order.from_checkout/3`, store the order, and `order_placed/2`. A declined instrument comes back as a `payment_failed` message with the checkout still open.
- **Cart**: create, get, update (full replacement), cancel.
- **Orders**: get, update (`Bazaar.Order.apply_update/2`: fulfillment events and adjustments), cancel refused with `:invalid_state` (override for what your fulfillment allows).
- **Catalog**: search on title and description with `Bazaar.Catalog` filters and pagination, lookup, get product with option availability.
- **Location**: search and lookup with `Bazaar.Location`, your `serves?/2` and `stocks?/2` as predicates.

Only the callbacks for the capabilities in `capabilities/0` are routed; the rest sit unused.

## Overriding a default

Every generated callback is `defoverridable`. Override it and call the default for the part you keep:

```elixir
@impl true
def cancel_order(id, conn) do
  case MyApp.Orders.cancellable?(id) do
    true -> {:ok, MyApp.Orders.cancel(id)}
    false -> Bazaar.Handler.Defaults.cancel_order(__MODULE__, id, conn)
  end
end
```

The callback signatures, for reference:

| Callback | Returns |
|---|---|
| `create_checkout(params, conn)` | `{:ok, checkout}` |
| `get_checkout(id, conn)` | `{:ok, checkout}` or `{:error, :not_found}` |
| `update_checkout(id, params, conn)` | `{:ok, checkout}`, `{:error, :not_found}`, `{:error, :invalid_state}` |
| `complete_checkout(id, params, conn)` | `{:ok, checkout}` (completed, or open with messages) |
| `cancel_checkout(id, conn)` | `{:ok, checkout}` |
| `create_cart`, `get_cart`, `update_cart`, `cancel_cart` | the cart document |
| `get_order(id, conn)`, `update_order(id, params, conn)`, `cancel_order(id, conn)` | the order document |
| `search_products`, `lookup_products`, `get_product` | `{:ok, %{"products" => ...}}` or `{:ok, %{"product" => ...}}` |
| `search_locations`, `lookup_locations` | `{:ok, %{"locations" => ...}}` |
| `link_identity(params, conn)` | `{:ok, map}` (no default) |
| `handle_webhook(payload)` | `{:ok, term}` (no default) |

## Error responses

The controller formats what a callback returns:

| Return value | HTTP status |
|---|---|
| `{:ok, map}` | 200, 201 on create |
| `{:error, :not_found}` | 404 |
| `{:error, %Ecto.Changeset{}}` | 422 with one message per error |
| `{:error, :invalid_state}`, `{:error, :unauthorized}`, other atoms | 422, the atom as the message code |
| `{:error, "message"}` | 422 |

## Sending order events

Platforms expect the full order document whenever an order is created or changes. The platform's profile (the URL in its `UCP-Agent` header, `conn.assigns.ucp_agent_profile`) says where to send it. `order_placed/2` is the place for the first one; later events use the same URL, so remember it with the order:

```elixir
@impl true
def order_placed(order, conn) do
  {:ok, url} = Bazaar.Platform.webhook_url(conn.assigns.ucp_agent_profile, http_client: &MyApp.Http.get/1)
  MyApp.Orders.remember_webhook(order["id"], url)
  event = Bazaar.Webhook.event(order, url)

  Task.Supervisor.start_child(MyApp.TaskSupervisor, fn ->
    Bazaar.Webhook.deliver(event, http_client: &MyApp.Http.post/3, signer: {signing_key(), base_url() <> "/.well-known/ucp"})
  end)
end
```

`deliver/2` retries transport errors and 5xx with the same body, `Webhook-Id` and `Webhook-Timestamp`, and treats 4xx as final. With a `:signer` it adds RFC 9421 signature headers; publish the key's public half so platforms can verify:

```elixir
@impl true
def business_profile do
  %{"name" => "My Store", "keys" => [Bazaar.Signing.Key.public_jwk(signing_key())]}
end

defp signing_key, do: Bazaar.Signing.Key.from_pem(File.read!(System.fetch_env!("UCP_SIGNING_KEY_PEM")))
```

## Testing

`Bazaar.Test` drives the controller the way `bazaar_routes` does and validates documents against the spec:

```elixir
import Bazaar.Test

test "roses are priced from the catalog" do
  {201, checkout} = request(MyApp.CommerceHandler, :create_checkout, checkout_request(%{"line_items" => [%{"item" => %{"id" => "roses"}}]}))
  assert_valid(checkout, :checkout)
  assert [%{"item" => %{"price" => 3500}}] = checkout["line_items"]
end
```

Start `Bazaar.Store.ETS` in your `test_helper.exs` when the handler uses it.

## Rolling your own routes

`bazaar_routes` is a convenience. To own the routes and controllers, build the discovery document with `Bazaar.DiscoveryProfile.from_handler/2`, call the handler's callbacks from your own actions, and keep the plugs. [examples/flower_shop](https://github.com/georgeguimaraes/bazaar/tree/main/examples/flower_shop) mixes both: `bazaar_routes` for the spec's routes and two hand-written ones for what the conformance suite needs beyond it.
