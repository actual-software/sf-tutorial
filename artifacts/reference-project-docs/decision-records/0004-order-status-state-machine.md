# ADR 0004: Order status state machine

- Status: Accepted
- Date: 2026-10-14

## Context

The manifest defines a linear lifecycle, `placed → preparing → ready → delivered`, with `cancelled` allowed only from `placed` or `preparing` and no backtracking. Every transition writes an `OrderStatusEvent`. `docs/PROJECT_OVERVIEW.md` asked whether backtracking is needed; the manifest answers no. The Review Standards require that every change go through one transition service and that illegal transitions are rejected. Several staff members may click the same order at nearly the same moment.

## Decision

1. Statuses are `placed`, `preparing`, `ready`, `delivered`, and `cancelled` (`ORDER_STATUSES` in `shared/src/domain.ts`). New orders start as `placed`. `delivered` and `cancelled` are terminal.
2. The legal transitions are `placed → preparing`, `preparing → ready`, `ready → delivered`, `placed → cancelled`, and `preparing → cancelled`. Everything else is illegal: backtracking, skipping a step, leaving a terminal status, and "transitioning" to the current status.
3. The transition table lives once, in `shared/src/order-status.ts`. The client uses it only to decide what to show, such as which button a card offers. The server enforces it.
4. `server/src/services/order-status.ts` is the only code that changes `orders.status`; its SQL lives in `server/src/repositories/order-status.ts`. In one transaction it updates `status` and `updated_at` and inserts an `order_status_events` row (`from_status`, `to_status`, `changed_at`). Creating an order writes the initial event (`from_status` NULL → `placed`) in the same transaction as the order insert.
5. The update is conditional on the expected current status (`WHERE id = ? AND status = ?`). A concurrent change makes it affect zero rows, so the request fails instead of advancing the order twice.
6. Illegal transitions and lost races return HTTP 409 `ILLEGAL_STATUS_TRANSITION` with `details: { currentStatus, requestedStatus }`. Unknown orders return 404 `NOT_FOUND`.

## Consequences

- The audit trail is complete: every order has one event per status it entered.
- Fixing a mistake (for example "ready" clicked too early) is impossible in the MVP. Staff cancel only while that is still allowed. Adding a correction path needs a new ADR.
