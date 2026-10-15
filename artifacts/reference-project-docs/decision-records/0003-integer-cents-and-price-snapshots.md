# ADR 0003: Integer cents and price snapshots

- Status: Accepted
- Date: 2026-10-14

## Context

The manifest stores all money as integer cents and snapshots prices onto order items, so later menu changes never alter existing orders (Per-Feature Success Criterion 6). The Security standards forbid trusting client-sent prices. `docs/PROJECT_OVERVIEW.md` left open whether to cache prices on order items or recompute them at display time. This ADR settles it: snapshot.

## Decision

1. Money is integer cents everywhere: database columns, shared types, and JSON fields, all with a `Cents` / `_cents` suffix. Dollars appear only when the client formats a value for display.
2. Pricing formula:
   - `unitPriceCents = Math.round(basePriceCents × size.priceMultiplier) + crust.priceDeltaCents + Σ topping.priceCents`
   - `lineTotalCents = unitPriceCents × quantity`
   - `order.totalCents = Σ lineTotalCents`

   It is implemented once, as pure functions in `shared/src/pricing.ts`. The client uses it for estimates and the server for authoritative totals.

3. The server never trusts client-sent prices. `POST /api/orders` accepts ids and quantities only, and validation strips any price fields. The server loads current catalog rows, rejects unavailable items and toppings, and computes every price itself.
4. Prices are snapshotted when the order is placed, into `order_items.unit_price_cents`, `order_item_toppings.price_cents`, and `orders.total_cents`. Reads of existing orders take money only from these columns, never from current menu prices. Menu edits therefore never change an existing order.
5. Prices the client computes before checkout (builder, cart) are estimates. The order confirmation shows the totals the server returned.

## Consequences

- Order history is stable and auditable, and totals never drift.
- Client and server compute prices with the same function, so a correct estimate and the final total always agree for the same catalog data.
- Display names (menu item, topping) are not snapshotted. An order shows an item's current name, which the MVP accepts.
