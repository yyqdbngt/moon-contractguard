# Implemented architecture

## Core

OpenAPI 3.0 JSON operation inventory; local schema references; typed request parameters; JSON request/response schemas; required fields and additionalProperties; enum/nullable; numeric/string/array/object bounds; uniqueItems; allOf/anyOf/oneOf; bounded validation. Compatibility diff detects removed operations and newly required inputs, with other changes classified for review. scripts/http.mjs checks actual HTTP responses.

## Boundaries

A documented OpenAPI 3.0 JSON profile, not complete OpenAPI compliance. Unsupported schema assertions set complete=false; valid=true alone is insufficient. External references, YAML, pattern/format/discriminator/not, response header constraints and non-JSON media are not verified. Compatibility changes with uncertain semantics are review, never automatically declared safe. Path parameter data is path_parameters; path itself is the route template. Query/header parameters must be supplied as typed values matching their schema. Redirects are rejected, response cap 1 MiB, request timeout 10 seconds. HTTP checks can execute supplied methods; use a selected test endpoint.

## Integration

The core accepts semantic values and returns deterministic JSON-shaped reports. Host adapters handle files, network or processes; they invoke the compiled MoonBit engine. The CLI package declares `supported_targets = "js"`; other backends test the portable core.

## Validation evidence

Fixture cases are hand-checked assertions. Independent reference checks and integration scripts are runnable from a clean checkout. CI executes four core backends and host checks. Historical proposal targets are not release results.
