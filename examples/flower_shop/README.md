# Flower Shop

A small UCP merchant built on Bazaar, and the server the official [UCP conformance suite](https://github.com/Universal-Commerce-Protocol/conformance) runs against in CI.

It sells the suite's flower shop catalog (six products, three discount codes, free shipping on roses or orders over $100, US and international express rates, a couple of known customers with stored addresses) from memory. No database.

`FlowerShop.Handler` implements `Bazaar.Handler` and `bazaar_routes` mounts discovery, checkouts and orders for it. The app adds its own pipeline in front (version negotiation on the `UCP-Agent` header, idempotent replay on `Idempotency-Key`) and three routes the suite needs beyond the UCP REST binding: `PUT /orders/:id`, the simulate-shipping hook and `/healthz`.

## Run it

```bash
mix deps.get
PORT=8182 SIMULATION_SECRET=super-secret-sim-key mix run --no-halt
curl http://localhost:8182/.well-known/ucp
```

`FLOWER_SHOP_URL` sets the absolute URL advertised in discovery (default `http://localhost:8182`).

## Run the conformance suite

With the app running and [uv](https://docs.astral.sh/uv/) installed:

```bash
bin/conformance
```

The script clones the suite at a pinned commit into `tmp/`, installs it with `uv sync --no-sources`, and runs every test file with `conformance/conformance_input.json`, which declares the spec version this app speaks. Two signed-webhook tests and the discovery URL test skip by design; everything else has to pass.

## Layout

| Module | Role |
|---|---|
| `FlowerShop.Catalog` | products, stock, discounts, promotions, shipping rates, customers |
| `FlowerShop.Checkout` | checkout state and the document built from it: pricing, stock messages, shipping options, discounts |
| `FlowerShop.Orders` | order documents, `PUT /orders/:id` merges, shipping events |
| `FlowerShop.Payments` | mock payment handler (`fail_token` declines) |
| `FlowerShop.Webhooks` | platform profile lookup and background order event delivery |
| `FlowerShop.Handler` | the `Bazaar.Handler` tying it together |
| `FlowerShopWeb.*` | endpoint, router with `bazaar_routes`, the extra plugs and controllers |
