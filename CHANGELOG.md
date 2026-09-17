# Changelog

## [0.3.0](https://github.com/georgeguimaraes/bazaar/compare/v0.2.2...v0.3.0) (2026-09-17)


### ⚠ BREAKING CHANGES

* Bazaar.Order.from_checkout/3 returns order line items with quantity {total, fulfilled} and a status, plus fulfillment expectations; the Bazaar.Fulfillment *_fields functions are gone, only the type lists and default configs remain.
* Bazaar.Webhook.event/2 and deliver/2 replace send/5, Bazaar.Webhook.Delivery, Bazaar.Webhook.Signature and Bazaar.WebhookEvent; deliveries carry the raw order with Webhook-Id and Webhook-Timestamp instead of an event envelope with a request-signature JWT; Bazaar.Platform.discover/2 takes the profile URL and discovery_url/1 is gone; retry defaults are 3 attempts from 500ms.
* error bodies are now UCP error responses on UCP routes and ACP Error objects on ACP routes; Bazaar.Errors.from_changeset/1, from_reason/1 and not_found/2 are replaced by Bazaar.Errors.response/2 and changeset_details/1; Bazaar.Plugs.Idempotency requires a running store and halts on replay or conflict; Bazaar.Plugs.UCPHeaders rejects mismatched versions unless configured with version: false.
* bazaar_routes mounts PUT /checkout-sessions/:id, POST /checkout-sessions/:id/complete and POST /checkout-sessions/:id/cancel instead of PATCH, POST .../actions/complete and DELETE.
* profile output changed shape (registries keyed by name, keys[] replaces signing_keys, merchant is top level); fulfillment config keys are multi_destination and method_combinations (arrays) instead of the allows_* booleans; Bazaar.Order.from_checkout/3 raises without a currency; Bazaar.Schemas.Shopping.Order is Bazaar.Schemas.Shopping.OrderResp; message types live under Bazaar.Schemas.Common.Types; priv/ucp_schemas/2026-01-23 is gone.

### Features

* Flower shop example that passes the UCP conformance suite ([2c86f0d](https://github.com/georgeguimaraes/bazaar/commit/2c86f0dfbaec89c0bc7a0c8fc8515e73a9b88972))
* Idempotent replay, version negotiation and spec-shaped errors ([66d5134](https://github.com/georgeguimaraes/bazaar/commit/66d5134994ea557f8f540d443daa416a879e2426))
* One plug for the UCP pipeline, spec-valid order helpers, Cachex idempotency store ([694487e](https://github.com/georgeguimaraes/bazaar/commit/694487efa558a1481b49883b966bd02f84473fde))
* Reserve idempotency keys before the action and keep only 2xx and 4xx ([2c278d3](https://github.com/georgeguimaraes/bazaar/commit/2c278d30df4e7f2c9572d9743dc3f5d3ab136095))
* Spec-shaped webhooks with RFC 9421 signing, platform profile lookup, order updates ([5674da8](https://github.com/georgeguimaraes/bazaar/commit/5674da86d80dd24d6580938a9258d8102ec7999d))
* Upgrade to UCP spec 2026-08-25 ([ce64e9d](https://github.com/georgeguimaraes/bazaar/commit/ce64e9d5f9e65686d9d8975eedae6675fbd1bccb))


### Bug Fixes

* **ci:** Pin setup-uv to an existing tag, its major tags stop at v7 ([7ef07ca](https://github.com/georgeguimaraes/bazaar/commit/7ef07ca061b1c3c98ba64de52f2155c81d3058c2))


### Miscellaneous

* Add a script that rebuilds the UCP schema tree for a spec version ([50bb337](https://github.com/georgeguimaraes/bazaar/commit/50bb33732b9f965c7777f56dc0a010afc8469306))
* Add Dependabot for mix and GitHub Actions ([#6](https://github.com/georgeguimaraes/bazaar/issues/6)) ([8e0bc0e](https://github.com/georgeguimaraes/bazaar/commit/8e0bc0ec453a87870b891c2a8e46d20b3b20c085))
* **deps:** Bump deps and align the CI matrix with dayoff and soothsayer ([926413f](https://github.com/georgeguimaraes/bazaar/commit/926413f9449c937c7b0ee740f52b1b4e5e7550a6))
* Pin Dependabot commit prefix to chore(deps) ([cf4d86c](https://github.com/georgeguimaraes/bazaar/commit/cf4d86c739f5796366f18015ce2e42f791c1b2e4))


### Documentation

* Point the install snippet at the current release ([2724bfe](https://github.com/georgeguimaraes/bazaar/commit/2724bfe7f80951d2c5d53e21584d1a6fe0c73d1d))
* Record what the UCP conformance suite expects from a merchant server ([8373653](https://github.com/georgeguimaraes/bazaar/commit/8373653227bce6e79a6468bd64ead96ce0e1a7de))

## [0.2.2](https://github.com/georgeguimaraes/bazaar/compare/v0.2.1...v0.2.2) (2026-02-07)


### Documentation

* rewrite README to give ACP equal coverage ([c62317a](https://github.com/georgeguimaraes/bazaar/commit/c62317aff8f2c6c4ec955f6f6ffce4527c2b95ca))


### Code Refactoring

* move UCP schemas under schemas/ucp/ parent directory ([1432c80](https://github.com/georgeguimaraes/bazaar/commit/1432c80338553cbcb296993c8fcba0970f94abde))

## [0.2.1](https://github.com/georgeguimaraes/bazaar/compare/v0.2.0...v0.2.1) (2026-02-07)


### Features

* add OpenAI product feed schema to validator ([b1eaf75](https://github.com/georgeguimaraes/bazaar/commit/b1eaf7542e567e90b651163cb954ae50129d289c))


### Bug Fixes

* normalize Message.parse return type and tighten retry error matching ([845b9d5](https://github.com/georgeguimaraes/bazaar/commit/845b9d50393d9d959ad836e7c6e17a2781a182ff))


### Miscellaneous

* exclude mix tasks from hex package ([6a17499](https://github.com/georgeguimaraes/bazaar/commit/6a17499a8ced2ffe1719f46b53f1d9f39b3e31c1))


### Code Refactoring

* remove unnecessary wrappers and dual string/atom handling ([3b1653a](https://github.com/georgeguimaraes/bazaar/commit/3b1653ad2298f0fc610beced05c82543bc86190b))
* remove validate_openai_product_feed/1 convenience function ([9840351](https://github.com/georgeguimaraes/bazaar/commit/984035134780f695fc269998eaa0efa4881c6101))
* replace JSON Schema with Ecto embedded schema for product feed ([c9b6a4b](https://github.com/georgeguimaraes/bazaar/commit/c9b6a4b6a7efbffb0d68754924b4ddacd899d8a9))
* version ACP schemas and make return_policy conditionally required ([1031bb4](https://github.com/georgeguimaraes/bazaar/commit/1031bb44105ebe9385c7e302b25e777b2e5334ec))

## [0.2.0](https://github.com/georgeguimaraes/bazaar/compare/v0.1.1...v0.2.0) (2026-01-26)


### ⚠ BREAKING CHANGES

* UCP schema structure changed significantly:
    - capabilities, services, payment_handlers are now objects keyed by
      reverse-domain name instead of arrays
    - payment_handlers required in checkout responses
    - new entity base schema with version/spec/schema/id/config
    - schema variants: platform_schema, business_schema, response_*_schema

### Features

* upgrade to UCP spec 2026-01-23 ([b94d8c5](https://github.com/georgeguimaraes/bazaar/commit/b94d8c5ae56dc4a7f411d868c3d0a080821ca6a9))


### Bug Fixes

* **ci:** chain hex-publish in release-please workflow ([dd3efdd](https://github.com/georgeguimaraes/bazaar/commit/dd3efdd5cded86bad133be9c5a0a25110db1732e))


### Documentation

* add product schema comparison table to protocols guide ([69efb8f](https://github.com/georgeguimaraes/bazaar/commit/69efb8f54f1d252b1bf6ea03b8cb794290e3e025))

## [0.1.1](https://github.com/georgeguimaraes/bazaar/compare/v0.1.0...v0.1.1) (2026-01-21)


### Bug Fixes

* preserve ok tuple through telemetry span in catalog controller ([505d168](https://github.com/georgeguimaraes/bazaar/commit/505d16877c233a01a0e407fe847ed508dcb4f14a))


### Miscellaneous

* add release-please config ([a53d857](https://github.com/georgeguimaraes/bazaar/commit/a53d857138a76b8ab0cc8bffbe503e053a114b61))
* regenerate schemas with fixed whitespace ([94fa364](https://github.com/georgeguimaraes/bazaar/commit/94fa3649a353403fbbeab2121221394b494af45d))


### Documentation

* add protocols.md to docs extras ([f043d03](https://github.com/georgeguimaraes/bazaar/commit/f043d032e45ebb2f242cb99907bd9cb6da267adc))
