# Project Manifest: Fired Up Pizza

## Overview

Fired Up Pizza is a web application for a small neighborhood pizza restaurant. Customers browse the menu, customize pizzas (size, crust, toppings), place an order against their phone number, and track it through `placed → preparing → ready → delivered` (or `cancelled`). Staff use the same application to manage menu items and toppings, watch the live order queue, and advance order status as pizzas move through the kitchen. It replaces a phone-only workflow that loses orders, garbles customizations, and can't tell customers when food is ready. Greenfield build, deliberately lean: the restaurant runs it themselves on a single machine with no third-party platform, payment processor, auth provider, or real-time infrastructure.

## Tech Stack

| Layer    | Technology | Notes |
|----------|-----------|-------|
| Frontend | React 18 + TypeScript, Vite | Customer app and staff dashboard served from one codebase |
| Styling  | Tailwind CSS | Utility-first; no component library |
| State    | React hooks + Context | No external state manager |
| Routing  | React Router v6 | Customer routes and `/staff/*` routes |
| Backend  | Node.js + Express | REST API |
| Database | SQLite via `better-sqlite3` | Single file, zero external server |
| Testing  | Vitest + React Testing Library | Backend routes tested with Vitest (+ supertest) |
| Linting  | ESLint + Prettier | Enforced on every PR |

## Project Structure

(proposed — update when scaffolded)

```
fired-up-pizza/
├── client/                 # React 18 + Vite frontend
│   ├── src/
│   │   ├── components/     # Shared UI components
│   │   ├── pages/
│   │   │   ├── customer/   # Menu, builder, cart, order tracking
│   │   │   └── staff/      # Order queue, menu management
│   │   ├── context/        # React Context providers (cart, staff session)
│   │   ├── hooks/          # Data fetching + polling hooks
│   │   ├── api/            # Typed REST client
│   │   └── main.tsx
│   └── index.html
├── server/                 # Express REST API
│   ├── src/
│   │   ├── routes/         # menu, orders, staff routes
│   │   ├── db/             # better-sqlite3 connection, migrations, seed
│   │   ├── services/       # Pricing, order status transitions
│   │   └── index.ts
├── shared/                 # Shared TypeScript types (domain model)
├── docs/                   # Manifests, ADRs (docs/adr/), overview
├── work-packages/          # Planner output
├── design/                 # Designer specs
├── review-reports/         # Reviewer output
├── release-gates/          # Deployer output
└── package.json            # Root scripts: `npm run dev` starts client + server
```

## Domain Model

All money is stored as integer cents.

- **MenuItem**: `id`, `name`, `description`, `category`, `base_price_cents`, `available` (boolean), `created_at`
- **Size**: `id`, `name` (S/M/L), `price_multiplier`
- **Crust**: `id`, `name`, `price_delta_cents`
- **Topping**: `id`, `name`, `price_cents`, `available` (boolean)
- **Order**: `id`, `phone_number`, `status` (`placed | preparing | ready | delivered | cancelled`), `total_cents`, `notes`, `created_at`, `updated_at`
- **OrderItem**: `id`, `order_id → Order`, `menu_item_id → MenuItem`, `size_id → Size`, `crust_id → Crust`, `quantity`, `unit_price_cents` (snapshot at order time)
- **OrderItemTopping**: `order_item_id → OrderItem`, `topping_id → Topping`, `price_cents` (snapshot at order time)
- **OrderStatusEvent**: `id`, `order_id → Order`, `from_status`, `to_status`, `changed_at` (audit trail)
- **Customer**: no entity — identified by `phone_number` on Order
- **Staff**: no entity — a role only

Relationships: Order 1—N OrderItem; OrderItem N—1 MenuItem, Size, Crust; OrderItem 1—N OrderItemTopping N—1 Topping; Order 1—N OrderStatusEvent.

Rules:
- **Pricing**: prices are snapshotted. `unit_price_cents = round(base_price_cents × size.price_multiplier) + crust.price_delta_cents + Σ topping price_cents`. `Order.total_cents = Σ unit_price_cents × quantity`. Later menu price changes never alter existing orders.
- **Status transitions**: linear `placed → preparing → ready → delivered`; `cancelled` allowed only from `placed` or `preparing`. No backtracking. Every transition writes an OrderStatusEvent.
- **Identity**: phone number is the MVP identity; isolate it behind one module so it can be swapped for magic link / OTP later.

## Conventions

(default — update when scaffolded)

- File naming: React components `PascalCase.tsx`; hooks `useCamelCase.ts`; all other files `kebab-case.ts`
- Test files: co-located `*.test.ts` / `*.test.tsx`
- API routes: REST under `/api`, plural resource nouns, kebab-case (e.g. `GET /api/menu-items`, `POST /api/orders`, `PATCH /api/orders/:id/status`); JSON bodies with camelCase keys
- Commits: Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`)
- Branches: `fired-up-pizza-<feature>` per work item, merged to `main` via PR after the Deployer gate passes

## Constraints

- Must run with `npm install && npm run dev` — zero additional setup
- No external database server — SQLite only
- No online payments — "pay at counter" model
- No real-time push (WebSockets, SSE, push notifications, SMS) — polling or manual refresh only
- No external auth provider — customers identified by phone number lookup only
- No container or cloud deployment target for MVP (VPS deploy is a future milestone)
- No component library — Tailwind utilities only
- No external state manager — hooks + Context only
- No observability, analytics, or comms integrations for MVP
- Out of scope: multi-location support, loyalty accounts

---

## Task Inputs

(pipeline-critical — verify before running factory)

| Agent     | Receives                  | From                     |
|-----------|--------------------------|--------------------------|
| Planner   | Feature request (GitHub Issue or `tickets.md` entry) + full PROJECT_MANIFEST.md | Human / issue tracker |
| Architect | Work package naming affected entities (e.g. Order, OrderItem, MenuItem) + Tech Stack, Constraints | Planner (`work-packages/`) |
| Designer  | Approved ADR + Domain Model (entities, pricing rules, status transitions) | Architect (`docs/adr/`), after Gate 1 |
| Coder     | UX/interaction spec with API contracts + Conventions | Designer (`design/`) |
| Reviewer  | Code diff on feature branch + spec + Review Standards | Coder (feature branch PR) |
| Deployer  | Approved review report + Release Criteria | Reviewer (`review-reports/`), after Gate 2 |

## Services to Connect

| Service | Purpose | Config |
|---------|---------|--------|
| GitHub | Source control, pull requests, standard PR flow | Public repo |
| GitHub Issues or `tickets.md` | Backlog that the Planner syncs feature requests from | Whichever the Planner is configured for |

## Success Criteria

### Per-Feature Success

- [ ] Customer places a customized order (size, crust, toppings) with only a phone number — no phone call
- [ ] Customer looks up orders by phone number and sees current status (polling ≤ 15s)
- [ ] Staff sees all live orders in one queue view
- [ ] Staff advances order status in one click; cancel allowed only from `placed` / `preparing`
- [ ] Staff creates, edits, and hides menu items and toppings
- [ ] Order totals match snapshotted prices (unaffected by later menu changes)

### Factory-Level Success

- [ ] `npm install && npm run dev` works on a clean checkout with no extra setup
- [ ] All tests and lint pass on a clean checkout
- [ ] Every feature passes both human gates and ships with an ADR, design spec, review report, and release gate

---

## Review Standards

(default — customize for this project)

### Spec Compliance

- Every behavior in the Designer's spec is implemented and covered by a test
- Order status changes go through the single transition service; illegal transitions (backtracking, cancelling from `ready`/`delivered`) are rejected and tested
- Prices are snapshotted to OrderItem / OrderItemTopping at order time; totals computed in integer cents
- Staff-facing flows (order queue, status advance, menu management) get disproportionate scrutiny: loading, empty, error, and stale-poll states all covered
- No feature violates a Constraint (no WebSockets, no external auth, no payment code, no extra services)

### Style

- TypeScript strict mode; no `any` without a justifying comment
- ESLint + Prettier clean
- Tailwind utilities only; no component library, no ad-hoc CSS files beyond the Tailwind entry
- State via hooks + Context; no external state manager
- Domain types imported from `shared/`, not redeclared

### Security

- All SQL uses `better-sqlite3` prepared statements with bound parameters — no string-built queries
- Validate and normalize phone numbers and all request bodies server-side
- Never trust client-sent prices; server recomputes `unit_price_cents` and `total_cents`
- Staff routes are separated under `/api/staff/*` and `/staff/*` so access control can be added in one place
- Order lookup by phone returns only that phone's orders; no endpoint lists all customers' phone numbers to non-staff routes

### Severity Scale

- **Low**: cosmetic issues, minor inconsistencies
- **Medium**: functional gaps, missing edge cases
- **High**: data loss, security vulnerability, spec violation

---

## Release Criteria

(default — customize for this project)

### Required (all must PASS)

1. [ ] Reviewer report approved at Gate 2 with zero open High-severity findings
2. [ ] `npm test` passes on a clean checkout
3. [ ] `npm run lint` passes with no errors
4. [ ] `npm install && npm run dev` starts client and server on a clean checkout with no extra setup
5. [ ] Database migrations apply cleanly to an empty SQLite file and to the previous schema
6. [ ] Feature's per-feature Success Criteria verified manually in the running app (staff flows included)
7. [ ] No Constraint violated (no new external services, dependencies requiring servers, or real-time infra)

### Informational (reported but non-blocking)

- Test coverage percentage for changed files
- Count of Medium/Low review findings deferred
- Production bundle size delta
- New npm dependencies added
