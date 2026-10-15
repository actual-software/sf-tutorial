# ADR 0007: Client state, data fetching, and polling

- Status: Accepted
- Date: 2026-10-14

## Context

The manifest fixes React 18 with hooks + Context (no external state manager), React Router v6, Tailwind with no component library, and no real-time push: order status refreshes by polling at 15 seconds or faster. The Review Standards require staff flows to cover loading, empty, error, and stale-poll states.

## Decision

1. React 18 function components and hooks. App state uses `useState` / `useReducer` and React Context only, for example the cart. No Redux, Zustand, MobX, React Query, SWR, or similar.
2. Routing uses React Router v6, with the route table in `client/src/App.tsx`:
   - Customer: `/`, `/menu/:menuItemId`, `/cart`, `/order-confirmation/:orderId`, `/track`.
   - Staff: `/staff/orders` and `/staff/menu`; `/staff` redirects to the queue.
   - Unknown paths render the not-found page.
3. All HTTP goes through `client/src/api/`: typed functions per resource, built on one `http` helper that turns the ADR 0006 error shape into a typed `ApiError`. Components and hooks never call `fetch` directly.
4. Live views (order tracking, the staff queue) refresh by polling every 15 seconds at most (10 seconds by default) through a shared `usePolling` hook. The hook never overlaps requests, keeps the last good data when a poll fails, and stops on unmount. No WebSockets or server-sent events.
5. Every data-driven view renders explicit loading, empty, and error-with-retry states. Polled views also have a stale state: when the last poll failed, keep showing the last good data with its last-updated time. Staff views also show pending and error states for actions, and handle 409 responses by refreshing.
6. Styling uses Tailwind utility classes only. `client/src/index.css`, the Tailwind entry point, is the only stylesheet. No component libraries, CSS modules, or CSS-in-JS.
7. App-wide providers are added in `client/src/AppProviders.tsx`, which both `main.tsx` and the test helper (`client/src/test/render.tsx`) use.
8. Accessibility basics: semantic elements, labelled form controls, real buttons and links. Tests query by role and label.
9. Known advisory: React Router 6.x is affected by GHSA-wrjc-x8rr-h8h6, an open redirect through backslash paths in `<Link>` / `useNavigate`, fixed only in v7. The app must never pass user-controlled strings to `Link`, `Navigate`, or `navigate()`. Whether to upgrade to v7, which the manifest does not specify, is a separate decision for the project owner, tracked as bead `fup-hi8`.

## Consequences

- Each page owns its data loading through shared hooks, so behavior for loading, stale data, and errors stays consistent across pages.
- Polling at 10 seconds puts a handful of requests per minute per open screen on one local server, well within what SQLite and Express handle.
