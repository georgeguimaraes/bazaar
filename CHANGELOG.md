# Changelog

## [0.4.0](https://github.com/georgeguimaraes/bazaar/compare/v0.3.0...v0.4.0) (2026-09-20)


### ⚠ BREAKING CHANGES

* Bazaar.Plugs.UCP verifies signatures and signs responses; a pipeline that also mounts VerifySignature or SignResponse should drop them or pass verify_signatures: false and sign_responses: false.
* order_placed/2 and order_updated/2 deliver by default, so an override that delivered should call super or keep overriding; Bazaar.Handler.fulfillment_config/0 and Bazaar.Fulfillment are removed, the config is a Bazaar.Shop callback now.
* use Bazaar.Handler requires shop: and store:; complete_checkout/2 is complete_checkout(id, params, conn); the old bare-behaviour handler is gone.
* Bazaar.Fulfillment.destination_types/0 returns the spec's names, :shipping_address and :business_location, instead of :address and :pickup_location.
* ACP requests and responses follow the 2026-01-30 schemas; the old items/sku/product.id/base_amount shapes and buyer.shipping_address are gone.
* Bazaar.Checkout.new/1 and changeset/1 (delegates to the Smelter schema) are gone; new/2 now takes request params and returns checkout state.
* the catalog callbacks are now search_products/2, lookup_products/2 and get_product/2 (taking the request body); list_products/2 is gone. bazaar_routes mounts POST /catalog/search, /catalog/lookup and /catalog/product instead of the GET /products routes.
* Bazaar.Signing.HttpSignature.verify/2 returns {:ok, params} instead of :ok, and the generated modules for capabilities bazaar does not expose (Bazaar.Schemas.Common.* for location, loyalty, payment terms, split payments, payment authentication, AP2 mandates, actions and identity linking) are no longer part of the package.

### Features

* ACP translation against the 2026-01-30 schemas, validated both ways ([7e6327f](https://github.com/georgeguimaraes/bazaar/commit/7e6327f59c849f129953710eee3dfda9c09714bb))
* Advertise the older profiles a business still serves ([cc0b166](https://github.com/georgeguimaraes/bazaar/commit/cc0b166c58810ce708048de7cc43dbabaf30f1f4))
* Advertise transports the business serves itself ([60ad7fa](https://github.com/georgeguimaraes/bazaar/commit/60ad7fa4022bed64c064618e262b87a49e78e454))
* Bazaar.Shop and Bazaar.Store, every callback by default from use Bazaar.Handler ([b4c1ac5](https://github.com/georgeguimaraes/bazaar/commit/b4c1ac5b80d154ecbf8ee39064da8c1d3b05177c))
* Bazaar.Store.Ecto and mix bazaar.gen.store ([eb57316](https://github.com/georgeguimaraes/bazaar/commit/eb573163fbc6112f4dbfde1789095f5d11415ab2))
* Buyer consent in the spec's purpose map, answered in the platform's dialect ([8cbe170](https://github.com/georgeguimaraes/bazaar/commit/8cbe1708438ad2d89847d494866674940015e0e7))
* Cart capability with cart-to-checkout conversion ([d9412c5](https://github.com/georgeguimaraes/bazaar/commit/d9412c57bd2eb54364c68b3911cd9e5f2116e4a3))
* Catalog search, lookup and get product on the spec's binding ([fed5052](https://github.com/georgeguimaraes/bazaar/commit/fed505234917e77a30f6dce0f9dff6b4c6ce8b1e))
* Checkout document builder with the spec's update, totals and fulfillment rules ([6da7dd2](https://github.com/georgeguimaraes/bazaar/commit/6da7dd2da8b77646e452c97820b24034d76dbfc5))
* Inbound signature verification, keys mirror, generator pruning ([c3e3638](https://github.com/georgeguimaraes/bazaar/commit/c3e3638c0e8cdf7ccc0ea2ebccae9cf82f55f0ff))
* Location search and lookup on the spec's binding ([7065852](https://github.com/georgeguimaraes/bazaar/commit/7065852b37d7a48622b96c989e560129e61cc824))
* Loyalty and payment terms extensions on checkout, cart and orders ([abd0832](https://github.com/georgeguimaraes/bazaar/commit/abd08329044d1f68faaf09670859ff5ca4ef0813))
* mix bazaar.gen.handler scaffold and a getting-started guide to match ([b00702b](https://github.com/georgeguimaraes/bazaar/commit/b00702bd734ece6bedc2615613470fd36618fdc5))
* One plug, no supervision wiring, a default HTTP client ([9f90089](https://github.com/georgeguimaraes/bazaar/commit/9f90089d51de5ad1912f295be547290725caacb1))
* Order webhooks deliver themselves, one HTTP client per shop, no fulfillment knob ([0d67e8d](https://github.com/georgeguimaraes/bazaar/commit/0d67e8d4ff33d56e5752f8c816c5ef7e144bda8d))
* Pickup fulfillment at the business's locations ([2373ae5](https://github.com/georgeguimaraes/bazaar/commit/2373ae50f0c5fad85a84a5f93024592c2e67f581))
* Ship the schema generators so merchants can generate what bazaar leaves out ([8a80617](https://github.com/georgeguimaraes/bazaar/commit/8a8061795107199e3317e4bd8afaf851ba4389e6))
* Shops hear of every order change ([6da0358](https://github.com/georgeguimaraes/bazaar/commit/6da03586a58cfde3592c99b4fafe5ab51df546d9))
* Sign responses with RFC 9421 signatures ([6b4ed18](https://github.com/georgeguimaraes/bazaar/commit/6b4ed1882dbbf612ef46543b9e2e09912864dae0))
* Telemetry for every operation, documented, and a span on signature verification ([d530c43](https://github.com/georgeguimaraes/bazaar/commit/d530c43b530a4438179171850daa5862964ba040))


### Bug Fixes

* Cart options looked up by literal atom, generator roots name cart and catalog ([e9274df](https://github.com/georgeguimaraes/bazaar/commit/e9274df46eaf0d2875d5998c433e437cafb04f78))
* Catalog bodies without ids get a 422, error documents pass response validation ([2f9e467](https://github.com/georgeguimaraes/bazaar/commit/2f9e46758d958ec6bf09dedf4197bd18b58b7a1e))
* Extensions extend only what the handler advertises, malformed distance is a 422 ([fb79b0e](https://github.com/georgeguimaraes/bazaar/commit/fb79b0ed6545c34a58c2e1a8e034f59c6ba36af8))
* Idempotent replays carry the response's headers, signature included ([4e36994](https://github.com/georgeguimaraes/bazaar/commit/4e36994da270b5dc8a995cdae6282cbc99a1fbe0))
* Regenerate the schemas with smelter 0.1.5, arrays and scalar refs typed right ([c8cc6fd](https://github.com/georgeguimaraes/bazaar/commit/c8cc6fd29afcdab5a9490a23a21189cd4364ab6c))
* Response validation against the spec's JSON Schemas, checkouts always carry payment_handlers ([c698ffb](https://github.com/georgeguimaraes/bazaar/commit/c698ffb1121748790c7e37f855cae4512510123d))
* Response validation reports the leaf messages under JSV composition errors ([19fa21d](https://github.com/georgeguimaraes/bazaar/commit/19fa21dc3154ce921015ba917300818781a144dd))


### Miscellaneous

* Generate no transport envelopes, bazaar is REST only ([a795616](https://github.com/georgeguimaraes/bazaar/commit/a79561634cf6331acbf44307c45b21a66d7c61ef))


### Documentation

* Finish moving the handlers guide's checkout examples onto Bazaar.Checkout ([a633c56](https://github.com/georgeguimaraes/bazaar/commit/a633c56f5043989469d84f70ed3ff873182dff05))
* Point the install snippet at 0.3 ([5c33d3a](https://github.com/georgeguimaraes/bazaar/commit/5c33d3aa6101a6d7be7240bff77044078003666a))
* Protocols guide handler section on the current ACP translation ([8119be3](https://github.com/georgeguimaraes/bazaar/commit/8119be396081ebb6778d5ff50e0a01b6a738ce34))
* README covers UCP only until ACP is finished ([d16618d](https://github.com/georgeguimaraes/bazaar/commit/d16618dd8ee323361aced8235b37436cfd49ca42))
* README quick start lists the store and config the generator prints ([078a1b0](https://github.com/georgeguimaraes/bazaar/commit/078a1b02db67dcb44e241224958fb964a47939ce))
* Say what the conformance suite does with an advertised service ([ce659ed](https://github.com/georgeguimaraes/bazaar/commit/ce659ed81551a37f3137a68e652af4c2d855f0fa))
* Testing guide and handler moduledoc on Shop, Store and Bazaar.Test ([3119dd0](https://github.com/georgeguimaraes/bazaar/commit/3119dd0bac003323889a8cc4eeb3de7548f6cf6d))
* The Ecto store, the generator and response signing in the guides ([c7f3842](https://github.com/georgeguimaraes/bazaar/commit/c7f384283979bdeda8f55dcb7bbbf4a924c1e7ff))


### Code Refactoring

* Generate the handler delegations from the callback list ([73c7694](https://github.com/georgeguimaraes/bazaar/commit/73c7694e2818238062d6ff0538f2326fe00d303b))


### Tests

* Drive the capabilities the conformance suite skips through the flower shop's endpoint ([2e406d7](https://github.com/georgeguimaraes/bazaar/commit/2e406d71865bd0e9578e7e4a74de7a339e99b747))


### Continuous Integration

* Key the example build cache strictly on the lockfiles ([0d484cb](https://github.com/georgeguimaraes/bazaar/commit/0d484cba9f4d1365b4fac372ea64039d163ffe9f))


### Reverts

* Drop the supported_versions passthrough, bazaar serves the latest spec only ([39d513f](https://github.com/georgeguimaraes/bazaar/commit/39d513fea0a0dd249ecee6c76c6827a21f0d1eab))

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
