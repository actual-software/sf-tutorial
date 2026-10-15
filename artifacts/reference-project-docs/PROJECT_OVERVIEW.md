# Project Overview: Fired Up Pizza

## 1. What is this software?

Fired Up Pizza is a web application for a small neighborhood pizza restaurant that wants to let customers order online and let staff manage the flow of orders without paying for a third-party platform. Customers browse the menu, customize pizzas (size, crust, toppings), place an order against their phone number, and track its status from "placed" through "delivered". Staff use the same application to manage menu items, watch incoming orders, and advance order status as pizzas move through the kitchen.

The project replaces a phone-only ordering workflow that loses orders, garbles customizations, and can't tell customers when food is ready. The business value is very concrete: fewer lost orders, fewer angry phone calls, and a single canonical view of every order.

This is a greenfield build. No external auth provider, no payment processor, and no real-time infrastructure — MVP is deliberately lean so the restaurant can run it themselves on a single machine.

## 2. Size, Type, Languages, Resource Constraints

- **Size**: small SaaS-style web app — one frontend, one backend, one database. Expect a few dozen components and a handful of API routes.
- **Type**: customer-facing web app + staff dashboard, both served from the same codebase.
- **Languages / frameworks**:
  - Frontend: React 18 + TypeScript, Vite build tooling
  - Styling: Tailwind CSS (utility-first — no component library)
  - State: React hooks + Context (no external state manager)
  - Routing: React Router v6
  - Backend: Node.js + Express, REST API
  - Database: SQLite via `better-sqlite3` (single-file, zero external server)
  - Testing: Vitest + React Testing Library
  - Lint / format: ESLint + Prettier
- **Runtime / platform**: runs locally on a single machine via `npm run dev`. No container, no cloud deployment target for MVP.
- **Resource constraints**:
  - Must run with `npm install && npm run dev` — zero additional setup
  - No external database server (SQLite only)
  - No payment processing — "pay at counter" model
  - No real-time push — polling or manual refresh for order status
  - No external auth provider — customers are identified by phone number lookup only

## 3. Potential SDLC Service Integrations

- **Source control**: GitHub — public repo, standard PR flow
- **CI/CD / deployment**: none for MVP. Runs locally. A future milestone might deploy to a small VPS, but not yet in scope.
- **Issue tracking**: GitHub Issues or a simple `tickets.md` in-repo backlog — whichever the factory's Planner is configured to sync from
- **Observability**: none for MVP (single-machine deployment makes centralized observability overkill). May revisit if the app starts running on a VPS.
- **Comms**: none
- **Data / analytics**: none — SQLite is the only datastore

The factory itself will exercise the GitHub integration (pull requests, issue sync) and can reach for `packs/workshop` MCP servers if observability later becomes relevant.

## 4. Open Questions / Concerns

- **Order status transitions**: the current model is `placed → preparing → ready → delivered | cancelled`. Is that linear path rigid enough, or do we need backtracking (e.g., ready → preparing because something was wrong)?
- **Customization pricing**: toppings have prices, sizes are multipliers — the domain model needs to land on whether prices are cached on the order item or recomputed from the menu at display time.
- **Phone number as identity**: adequate for MVP, but will almost certainly need something sturdier (magic link, OTP) if the restaurant grows. The factory's ADRs should make it easy to swap this out later.
- **Testing strategy for the kitchen-facing dashboard**: the customer-facing flows are easier to reason about than the staff-facing ones. Want the Designer and Reviewer agents to pay disproportionate attention to staff flows.
