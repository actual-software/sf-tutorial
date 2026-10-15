# Coordination channels

How work moves between agents in this factory, and where to look when it stops moving.

This describes the factory as it actually runs for the `fired-up-pizza` rig: the `base-factory` pack (which pulls in `architect-rig` → `pr-gate-rig` → `setup`) at rig scope, plus the city-scoped `mayor` from `pr-gate-city`. The six-role pipeline in `SOFTWARE_FACTORY_MANIFEST.md` maps onto these agents as follows:

| Manifest role | Agent that carries it here |
| --- | --- |
| Planner | `mayor` (or a polecat slung a planning bead, as with `fup-be5`, which broke the project into epics and child beads) |
| Architect (Gate 1 input) | `fired-up-pizza/architect` (pool of 0–2), reviewing each diff against `docs/decision-records/` and `docs/current/` |
| Designer + Coder | `fired-up-pizza/polecat` (pool of 0–5), one bead per session, each in its own worktree |
| Reviewer | `fired-up-pizza/refinery` (single session): rebase, tests + lint, `verify-architect`, `approval-review` |
| Deployer | `refinery` `merge-push` step, then the human release sign-off |

There is **no witness session** in this city. Prompts that say "mail the witness" fall back to `mayor/`.

## Channel inventory

| Channel | Primitive | Persists a restart | Timing | Addressed to | Owner |
| --- | --- | --- | --- | --- | --- |
| Tasks | `gc bd` beads, `gc sling`, `assignee` + `metadata.gc.routed_to` | yes | next eligible pull by the pool's reconciler | a pool (`polecat`, `architect`, `refinery`) | refinery (routing between stages); mayor (initial dispatch) |
| Bead metadata (verdicts and handoff state) | `gc bd update --set-metadata` (`branch`, `target`, `rejection_reason`, `architect_approved`, `architect_feedback`, `review_loops`, `review_cap_reached`, `refinery_approved`, `blocked_reason`) | yes | read on the receiver's next patrol | whoever the bead is routed to | the agent that writes each field (see the refinery prompt's metadata table) |
| Bead notes | `gc bd note`, `gc bd update --append-notes` | yes | read when someone opens the bead | anyone reading the bead | the agent doing the work (never `--notes`, which wipes history) |
| Mail | `gc mail send` | yes | recipient's next turn | `mayor/` (escalations); self (`HANDOFF:`) | mayor (reads and triages); human operator (reads the mayor's inbox for release sign-off) |
| Orders | `gc order` (`factory-pulse` cron hourly, `bead-closed-log` on `bead.closed`) | yes (definition on disk) | schedule or event | the controller; output goes to `FACTORY_LOG.md` | human operator |
| Nudges | `gc session nudge` | no | immediate, if the session is alive | one session | sender (refinery nudges polecats after a bounce) |
| Session attach / peek | `gc session attach`, `gc session peek` | no | immediate | one session | human operator |

A channel with no owner is one nobody notices has broken. The orders are the easiest to lose: if `FACTORY_LOG.md` stops getting an hourly `pulse` line, the controller is down.

## Preferences by handoff

| Handoff | Primary | Fallback | Why |
| --- | --- | --- | --- |
| Human → front gate | Feature request to the `mayor`, which files beads (`gc bd create`) and slings them | Human runs `gc sling fired-up-pizza/polecat <bead>` directly | The mayor owns dispatch; a direct sling is fine when the bead already exists and the right formula is obvious |
| Front gate → implementer | `gc sling fired-up-pizza/polecat <bead>` (pool pull via `gc hook`) | `gc session nudge` the polecat with "Run gc hook" | A sling is durable and the pool reconciler wakes a polecat for it; a nudge only helps an already-live session notice it |
| Implementer → reviewer | Polecat pushes the branch, sets `metadata.branch`/`target`, reassigns the bead to `fired-up-pizza/refinery` **and** sets `gc.routed_to` | Mail `mayor/` if the handoff can't be completed (push fails, branch missing) | Without `gc.routed_to` the reconciler keeps counting the bead against the polecat pool and the refinery never sees it |
| Reviewer → implementer (bounce) | Refinery reopens the bead with `assignee=""`, `rejection_reason`, `gc.routed_to=…/polecat` | Refinery nudges a live polecat | The rejection metadata is the durable record; the next polecat reads it on pickup. Bounces are routine, so they are not mailed |
| Reviewer → architecture review | Refinery `verify-architect`: while `architect_approved` is unset, route the bead to `fired-up-pizza/architect` | Nudge the architect ("Check your hook") | Same pool-routing primitive as every other stage, so the architect pool scales from 0 on demand |
| Architecture review → reviewer | Architect writes `architect_approved` (+ `architect_feedback` on reject) and reassigns to the refinery | Architect mails `mayor/` if it can't reach a verdict (missing context) | The refinery, not the architect, counts `review_loops`. A rejection under the cap of 2 bounces to polecats; at the cap the refinery force-approves, sets `review_cap_reached=true`, and mails the mayor |
| Reviewer → human (merge) | Refinery `approval-review` then `merge-push`: direct merge to `main` on `origin` (or a PR when `merge_strategy=pr`), close the bead | Refinery mails `mayor/` with `BLOCKED at approval gate: <bead>` | Gate 2 is the refinery's approval step; the human sees results on `origin/main`, in `FACTORY_LOG.md` (`closed` lines), and in the mayor's inbox for anything held back |
| Any agent → human (blocked) | `gc mail send mayor/ -s "BLOCKED: …"` or `"ESCALATION: … [HIGH]"`, then `gc bd update --status=escalated` | Bead note describing the block, so the next reader sees it without the mail | Mail survives restarts and lands in the one inbox a human reads; a status alone is invisible unless someone is watching the board |
| Nothing → factory (scheduled sweeps) | Orders: `factory-pulse` (cron `0 * * * *`) and `bead-closed-log` (`bead.closed` event) | `gc order run <name>` by hand | Both only write `FACTORY_LOG.md`; nothing reads that file automatically, so a human has to look at it |

## Protocols

- **Routing means both fields.** Every handoff between pools sets `assignee` *and* `metadata.gc.routed_to` to the same target. Setting one without the other strands the bead outside every pool.
- **The bead is the record, mail is the alarm.** Verdicts, rejections, and branch names live in bead metadata. Mail is reserved for things a human or the mayor has to act on: escalations, approval-gate blocks, architect rejections, and the review cap.
- **Blocked work always mails `mayor/`, never only sets a status.** There is no witness here, so `mayor/` is the only inbox that gets read. Escalate, then `--status=escalated`, then drain and exit.
- **A nudge is never the only signal.** Nudges are for waking a live session to check its hook. If a nudge is the mechanism, the bead routing already carries the same intent, because a nudge to a dead session leaves no trace.
- **Never trust the rig-root checkout of `main`.** It lags `origin/main`; agents read ADRs and architecture docs with `git show origin/main:<path>`.
- **Notes are append-only.** Use `gc bd note` or `--append-notes`; `--notes` overwrites the bead's history.
- **Hold the claim.** Claims lease for 5 minutes; long-running polecat or architect work keeps a `gc bd heartbeat` going, or the bead returns to the pool mid-work.
- **Architect follow-ups get filed.** When an architect approves with a follow-up concern, the refinery files it as a bead or mails it to the mayor so it doesn't live only in `architect_feedback`.
- **Usage-limit stalls are escalated once.** If polecats and architects stop because of a usage limit, mail `mayor/` once and wait; don't re-sling the same beads.

## When the factory goes quiet

The diagnostic order that follows from the primaries above.

1. `tail FACTORY_LOG.md`: is there a `pulse` line for the last hour? If not, the controller/orders are down (`gc order check`, `gc order history`).
2. `gc bd list --status open` and `--status in_progress`: is there work, and who is it assigned/routed to? A bead assigned to a pool with no matching `gc.routed_to` is stranded.
3. `gc bd list --status escalated` and `gc bd show <bead> --json | jq '.[0].metadata'`: is something waiting on a human, or carrying a `rejection_reason` / `blocked_reason` / `review_cap_reached`?
4. `gc session list`: is a polecat, architect, or refinery alive that could pick it up? (The refinery is capped at 1, architects at 2, polecats at 5.)
5. `gc mail inbox mayor/`: is an escalation or `BLOCKED at approval gate` mail sitting unread?
6. `gc session peek <id>`: is an agent alive but stuck mid-turn (e.g. a usage-limit stall)?
7. `git log origin/main`: did the last "closed" bead actually land, or was the merge never pushed?

An idle factory with a steady hourly `pulse` line, no open-and-unblocked beads, and an empty mayor inbox is done, not broken. As of 2026-10-15 the MVP is merged (`fup-e6u.2` at `948c152`); the 11 beads still open are six epics awaiting closure and five follow-up bugs/decisions (`fup-vng`, `fup-3ex`, `fup-h1d`, `fup-cfa`, `fup-hi8`) that nobody has slung yet. Nothing is waiting on a stuck agent.
