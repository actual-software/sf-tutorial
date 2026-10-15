# ADR 0001: Monorepo layout and tooling

- Status: Accepted
- Date: 2026-10-14

## Context

The manifest fixes the stack (React 18 + TypeScript + Vite, Tailwind, React Router v6, Express, SQLite via `better-sqlite3`, Vitest + Testing Library, ESLint + Prettier). It also requires that `npm install && npm run dev` works on a clean checkout with no other setup. Up to five polecats work in parallel, and every merge is rebased onto `main`. Two branches editing the same lines cost a rejected merge and a fresh polecat session, so the layout must give each feature its own files.

## Decision

1. One repository with npm workspaces: `shared/` (`@fired-up-pizza/shared`), `server/` (`@fired-up-pizza/server`), `client/` (`@fired-up-pizza/client`). There is one root `package-lock.json`, and npm is the only package manager.
2. Root scripts are the supported entry points and the quality gates. `npm run dev` starts the API and the client. `npm test` runs Vitest. `npm run lint` runs ESLint with zero warnings plus a Prettier check. `npm run typecheck` runs `tsc --noEmit` for every workspace, and `npm run build` runs typecheck plus the client production build. `npm install && npm run dev` and every quality gate must work on a clean checkout with nothing else installed, on any Node version in the root `package.json` `engines` range: `^22.22.2 || ^24.15.0 || >=26.0.0`, with 24 pinned in `.nvmrc`. That range is where the Node ranges declared by every locked dependency overlap; today it is exactly jsdom 30's range. A dependency change that narrows the overlap updates `engines` and this rule in the same branch.
3. TypeScript everywhere: `strict` plus `noUncheckedIndexedAccess`, ES modules (`"type": "module"`), and `import type` for type-only imports. Do not use `any` without a comment that justifies it.
4. `shared/` holds domain types and pure domain rules only, with no Node, DOM, Express, React, or database imports. Domain entity types come from `@fired-up-pizza/shared`. Feature modules are separate files imported by subpath (for example `@fired-up-pizza/shared/pricing` resolves to `shared/src/pricing.ts`), so parallel work adds files instead of editing a shared index. The client and server never redeclare domain types.
5. Server layout under `server/src/`:
   - `index.ts`: the process entry, and the only module that opens the database file or binds a port.
   - `app.ts` (`createApp`) and `config.ts`.
   - `db/`: connection, migrations, seed.
   - `repositories/`: all SQL.
   - `services/`: business rules and transactions.
   - `routes/`: thin HTTP handlers, with staff routes under `routes/staff/`.
   - `identity/`: phone identity (ADR 0005).
   - `http/`: errors and validation.

   The server runs TypeScript through `tsx` in development and production; there is no server compile step.

6. Client layout under `client/src/`:
   - `main.tsx`, `App.tsx` (route table), and `AppProviders.tsx` (every context provider).
   - `api/`: HTTP.
   - `hooks/`, `context/`, `components/`.
   - `pages/customer/` and `pages/staff/`.
   - `lib/`: pure helpers.
   - `test/`: test setup and render helpers.
7. Development topology: the API listens on port 3001 (`PORT` overrides). The Vite dev server listens on 5173 and proxies `/api` to the API. The client always calls relative `/api/...` URLs.
8. Tests are co-located as `*.test.ts` / `*.test.tsx` and run as Vitest projects: `shared` and `server` in Node, `client` in jsdom with Testing Library. Server tests use in-memory SQLite, apart from the file-database tests that ADR 0002 rule 2 allows, and client tests mock `fetch`. No test may need a running server or the network.
9. Dependencies:
   - The scaffold installs the full MVP set: React 18, React Router 6, Tailwind 4, Express 5, `better-sqlite3`, zod, `tsx`, Vitest, Testing Library, supertest.
   - A new runtime dependency needs a justification in the commit body. It must not add an external service, an extra server process, a component library, a state manager, or a real-time transport.
   - Dependency install scripts are disabled (`.npmrc`: `ignore-scripts=true`), so every dependency must work from prebuilt binaries.
10. Parallel-work seams are pre-wired:
    - router mounts in `server/src/app.ts` and `server/src/routes/staff/index.ts`
    - the route table in `client/src/App.tsx`
    - the provider list in `client/src/AppProviders.tsx`

    Feature work fills in its own stub files and adds new files. It edits one of these registries only when its bead says so.

## Consequences

- Each bead owns a distinct set of files. Most merges rebase cleanly, and `package-lock.json` rarely changes after the scaffold.
- Type errors across the client/server boundary surface at typecheck time, because both import the same shared types.
- Running the server through `tsx` keeps the toolchain small. If a compiled build becomes necessary, add it with a new ADR.
