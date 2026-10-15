# ADR 0002: SQLite persistence and migrations

- Status: Accepted
- Date: 2026-10-14

## Context

The restaurant runs the app on one machine with no database server (manifest Constraints). Release Criterion 5 requires migrations that apply cleanly to an empty SQLite file and on top of the previous schema. The Security standards require prepared statements for all SQL. Orders must keep working after menu items change or are hidden.

## Decision

1. SQLite through `better-sqlite3` (synchronous API) is the only datastore. Each process has one connection, opened by `openDatabase()` in `server/src/db/connection.ts`. Foreign keys are always on; file databases use WAL journaling.
2. The database file defaults to `server/data/fired-up-pizza.sqlite`; `DATABASE_PATH` overrides it. Its directory is created automatically and is gitignored. Tests use `:memory:`. The one exception is a test of behavior that only a file database has, such as WAL journaling or migrating an empty file. Such a test opens a new file in a fresh temporary directory (`fs.mkdtempSync` under `os.tmpdir()`) and deletes the directory afterwards. No test opens the real database file.
3. Migrations:
   - The schema changes only through numbered SQL migrations in `server/src/db/migrations/NNNN_description.sql`, loaded relative to the module (`import.meta.url`).
   - They are applied at startup in filename order, each in its own transaction, and recorded in `schema_migrations(version, applied_at)`.
   - An applied migration is never edited; changes go in a new migration.
   - Every migration must apply to an empty database and on top of the previous schema.
4. Catalog seed data is inserted at startup only when the catalog tables are empty. Seeding never overwrites or deletes existing rows, so staff edits survive restarts.
5. All SQL lives in `server/src/db/` and `server/src/repositories/` and runs through prepared statements with bound parameters. Never concatenate or interpolate values into SQL. A dynamic fragment, such as a sort direction, must come from a fixed allowlist in code.
6. Storage conventions:
   - `snake_case` columns and integer primary keys
   - money as `INTEGER` cents with a `_cents` suffix
   - booleans as `INTEGER` 0/1 with `CHECK (column IN (0, 1))`
   - timestamps as ISO-8601 UTC `TEXT` (e.g. `2026-10-14T23:20:00.000Z`)

   Repositories map rows to the camelCase domain types from `@fired-up-pizza/shared`.

7. Rows referenced by orders are never hard-deleted. Menu items and toppings are hidden with `available = 0`. Foreign keys use `ON DELETE RESTRICT`.
8. Multi-statement writes, such as placing an order or changing its status, run inside `db.transaction()` so they are atomic.

## Consequences

- `npm run dev` on a clean checkout creates, migrates, and seeds the database with no manual step.
- The synchronous driver makes transactions simple and keeps request handling easy to follow. One process serves the whole restaurant, which suits a single machine.
- Hiding instead of deleting keeps order history intact, at the cost of staff screens needing a "show hidden" view.
