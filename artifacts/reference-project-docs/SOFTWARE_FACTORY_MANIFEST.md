# Software Factory Manifest: Fired Up Pizza

## Factory Overview

Fired Up Pizza — online ordering and staff order management for a single neighborhood pizza restaurant. This factory runs a 6-agent sequential pipeline (Planner → Architect → Designer → Coder → Reviewer → Deployer) with two human gates. Tech stack: React 18 + TypeScript + Vite frontend styled with Tailwind CSS (hooks + Context state, React Router v6), Node.js + Express REST backend, SQLite via `better-sqlite3`, tested with Vitest + React Testing Library and linted with ESLint + Prettier. Everything runs on one machine via `npm install && npm run dev`.

## Pipeline Sequence

1. **Planner**
   - Reads: feature request + PROJECT_MANIFEST.md
   - Writes: work-packages/fired-up-pizza.md

2. **Architect**
   - Reads: Planner work package + Tech Stack section
   - Writes: docs/adr/NNNN-fired-up-pizza.md

3. **Designer**
   - Reads: Architect ADR + Domain Model section
   - Writes: design/fired-up-pizza-spec.md

4. **Coder**
   - Reads: Designer spec + Conventions section
   - Writes: src/ on feature branch fired-up-pizza-[feature]

5. **Reviewer**
   - Reads: code diff + Review Standards section
   - Writes: review-reports/fired-up-pizza-review.md

6. **Deployer**
   - Reads: Reviewer report + Release Criteria section
   - Writes: release-gates/fired-up-pizza-gate.md

## Human Gates

- **Gate 1 — After Architect:** Human approves ADR before Designer runs.
- **Gate 2 — After Reviewer:** Human approves review report before Deployer runs.

## Per-Agent System Prompt Seeds

**Planner:** "You are the Planner for Fired Up Pizza. You decompose feature requests into work packages that name the affected entities (Order, OrderItem, MenuItem, Topping) using the Domain Model, Tech Stack, and Constraints in PROJECT_MANIFEST.md."

**Architect:** "You are the Architect for Fired Up Pizza. You write architectural decision records covering how Order, OrderItem, and OrderStatusEvent are stored and served, using the Tech Stack and Constraints in PROJECT_MANIFEST.md, keeping phone-number identity swappable."

**Designer:** "You are the Designer for Fired Up Pizza. You write UX specs, interaction designs, and API contracts for customer and staff flows around Order, MenuItem, and Topping, using the Domain Model and Conventions in PROJECT_MANIFEST.md, with extra attention to staff order-queue flows."

**Coder:** "You are the Coder for Fired Up Pizza. You implement features that create and update Order, OrderItem, and MenuItem records following the Conventions and Task Inputs in PROJECT_MANIFEST.md."

**Reviewer:** "You are the Reviewer for Fired Up Pizza. You enforce the Review Standards in PROJECT_MANIFEST.md against every code diff, checking Order status transitions and OrderItem price snapshots, and scrutinizing staff flows most closely."

**Deployer:** "You are the Deployer for Fired Up Pizza. You gate releases against the Release Criteria in PROJECT_MANIFEST.md, confirming Order and MenuItem migrations apply cleanly and the app starts with `npm install && npm run dev`."

## Quality Gates

**Stage 1 (Planner) passes when:** the work package names the affected Domain Model entities (e.g. Order, OrderItem, MenuItem, Topping), maps to at least one Per-Feature Success Criterion, and violates no Constraint (no payments, no real-time push, no external auth/DB/services).

**Stage 2 (Architect) passes when:** the ADR fits the Tech Stack (React 18/Vite, Express REST, SQLite via `better-sqlite3`), keeps `npm install && npm run dev` zero-setup, isolates phone-number identity behind one module, and is approved at Gate 1.

**Stage 3 (Designer) passes when:** the spec uses Domain Model entities and rules as defined (integer-cent price snapshots on OrderItem/OrderItemTopping; linear status path with cancel only from `placed`/`preparing`), defines REST contracts per Conventions, and covers loading, empty, error, and stale-poll states for every staff flow.

**Stage 4 (Coder) passes when:** code lives on branch `fired-up-pizza-<feature>`, follows Conventions (file naming, co-located `*.test.ts(x)`, `/api` kebab-case routes, Conventional Commits), every spec behavior has a test, and `npm test` and `npm run lint` pass locally.

**Stage 5 (Reviewer) passes when:** the report checks the diff against all Review Standards —
- Spec Compliance: every spec behavior implemented and tested; transitions go through the single transition service and illegal ones are rejected; prices snapshotted in integer cents; staff flows scrutinized; no Constraint violated
- Style: TypeScript strict, no unjustified `any`; ESLint + Prettier clean; Tailwind only; hooks + Context only; domain types from `shared/`
- Security: prepared statements only; server-side validation of phone numbers and bodies; server recomputes prices; staff routes under `/api/staff/*` and `/staff/*`; phone lookup returns only that phone's orders
- every finding rated Low / Medium / High, with zero open High findings — and the report is approved at Gate 2.

**Stage 6 (Deployer) passes when:** all Required Release Criteria PASS —
1. Reviewer report approved at Gate 2 with zero open High-severity findings
2. `npm test` passes on a clean checkout
3. `npm run lint` passes with no errors
4. `npm install && npm run dev` starts client and server on a clean checkout with no extra setup
5. Database migrations apply cleanly to an empty SQLite file and to the previous schema
6. The feature's Per-Feature Success Criteria are verified manually in the running app (staff flows included)
7. No Constraint violated

— and the gate file reports the informational metrics: test coverage for changed files, deferred Medium/Low findings, bundle size delta, and new npm dependencies.

## Orchestrator Configuration

- Coordination pattern: sequential pipeline with handoffs
- Failure handling: stop pipeline at failing agent, surface error to human
- Retry policy: no automatic retries (human decides whether to re-run)
- Branch strategy: feature branch per work item, merge after Deployer gate passes

## Conventions Reference

(default — update when scaffolded)

- File naming: React components `PascalCase.tsx`; hooks `useCamelCase.ts`; all other files `kebab-case.ts`
- Test files: co-located `*.test.ts` / `*.test.tsx`
- API routes: REST under `/api`, plural resource nouns, kebab-case (e.g. `GET /api/menu-items`, `POST /api/orders`, `PATCH /api/orders/:id/status`); JSON bodies with camelCase keys
- Commits: Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`)
- Branches: `fired-up-pizza-<feature>` per work item, merged to `main` via PR after the Deployer gate passes
