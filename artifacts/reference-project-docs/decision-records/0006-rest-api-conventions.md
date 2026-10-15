# ADR 0006: REST API conventions

- Status: Accepted
- Date: 2026-10-14

## Context

The client and server are built by different beads in parallel, so the API contract must be fixed up front. The manifest's Conventions and Security standards set the basics: REST under `/api`, kebab-case plural nouns, camelCase JSON, staff routes separated under `/api/staff/*`, and server-side validation of every request.

## Decision

1. All endpoints live under `/api`. Resource paths are plural kebab-case nouns. Request and response bodies are JSON with camelCase keys.
2. The contracted MVP endpoints are:
   - Customer: `GET /api/menu-items`, `GET /api/sizes`, `GET /api/crusts`, and `GET /api/toppings` (available rows only); `POST /api/orders`; `GET /api/orders?phone=…`.
   - Staff: `GET /api/staff/orders`; `PATCH /api/staff/orders/:id/status`; `GET` and `POST /api/staff/menu-items`, `PATCH /api/staff/menu-items/:id`; `GET` and `POST /api/staff/toppings`, `PATCH /api/staff/toppings/:id`.
   - Operations: `GET /api/health`.

   This refines the manifest's example `PATCH /api/orders/:id/status`. A status change is a staff action, so per the Security standards it lives under `/api/staff`.

3. Staff endpoints are mounted only through `server/src/routes/staff/index.ts`, behind `requireStaff` (`server/src/routes/staff/require-staff.ts`). That middleware is the single place access control will be added. Client staff pages live under `/staff/*`.
4. Every body, query, and path parameter is validated server-side with zod through `parseWith` (`server/src/http/validate.ts`). Object schemas strip unknown keys. Failures return 400 `VALIDATION_ERROR` with `details.issues: [{ path, message }]`.
5. Errors use one shape, `{ "error": { "code", "message", "details"? } }`, with codes from `shared/src/api-error.ts`. `server/src/http/errors.ts` maps each code to one status:

   | Code                        | Status |
   | --------------------------- | ------ |
   | `VALIDATION_ERROR`          | 400    |
   | `INVALID_PHONE_NUMBER`      | 400    |
   | `NOT_FOUND`                 | 404    |
   | `CONFLICT`                  | 409    |
   | `ILLEGAL_STATUS_TRANSITION` | 409    |
   | `ITEM_UNAVAILABLE`          | 422    |
   | `INTERNAL_ERROR`            | 500    |

   Routes and services throw `AppError`. Unexpected errors become a generic 500 with no internal details.

6. Success responses:
   - A single resource returns the object, a collection returns a JSON array, and creation returns 201.
   - IDs are integers, timestamps are ISO-8601 UTC strings, and money fields are `…Cents` integers.
   - A feature's request and response types live in a shared module, e.g. `shared/src/orders-api.ts`.
7. Routers are created by factory functions that receive `AppDependencies` (`{ db }`) from `createApp`, so tests run the real app against an in-memory database. Handlers stay thin: validate, call a service or repository, respond.
8. No WebSockets, server-sent events, long polling, payment endpoints, third-party auth, or calls to external services.

## Consequences

- Client beads can be written against these contracts before seeing the server code, and the shared request/response types keep both sides honest.
- Adding staff authentication later touches one middleware, not every route.
