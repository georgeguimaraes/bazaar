# Changelog

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
