# Changelog

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
