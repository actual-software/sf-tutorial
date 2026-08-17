# W5 · Observability and Traceability

**Workshop · 30 minutes · Day 1**

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context](#context)
- [Try It](#try-it)
  - [1. Open the dashboard](#1-open-the-dashboard)
  - [2. The beads list, and what a bead carries](#2-the-beads-list-and-what-a-bead-carries)
  - [3. Formula runs](#3-formula-runs)
  - [4. Agent sessions, live](#4-agent-sessions-live)
  - [5. The event log](#5-the-event-log)
  - [6. Reflect](#6-reflect)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

Your factory runs without you. This session is about seeing what it did and why. By the end you can answer "what happened to this piece of work" from either the browser or the command line, and you know which surface answers which question fastest.

## Prereqs

- [W4](./W4-tour-the-factory.md) complete, and at least one bead that has moved through the pipeline.
- The four env vars exported.

## Context

Three questions come up constantly once a factory is doing real work, and each has a different best surface.

| Question | Fastest answer |
| --- | --- |
| What is the state of everything? | the dashboard's beads list |
| Why did *this* piece of work end up like that? | the bead itself, its metadata and notes |
| What is that agent doing *right now*? | the session, peeked or attached |

The trap is using one surface for all three. A dashboard is excellent at breadth and poor at "why", because the reasoning lives on the bead. A session attach is excellent at "right now" and useless an hour later. Knowing which to reach for is the whole skill.

Everything below has a CLI form and a browser form. Neither is authoritative over the other; they read the same store.

## Try It

### 1. Open the dashboard

The dashboard is a single-page app embedded in the `gc` binary and served by the supervisor, so nothing separate needs starting.

**Copy and paste**

```bash
cd "$FACTORY_PATH"
gc dashboard
```

That resolves the supervisor URL, opens your browser, and prints the URL as well. If you are on a cloud box, the browser is on your laptop and the supervisor is not:

**Copy and paste**

```bash
gc dashboard --no-open      # on the box: print the URL, do not try to open it
sfbox dashboard             # on your laptop: tunnel it to 127.0.0.1:8372
```

`sfbox dashboard` opens an SSH tunnel and runs in the foreground until `Ctrl-C`.

### 2. The beads list, and what a bead carries

Find the beads list in the dashboard, then pick the bead you watched move in W4.

A bead is not just a title and a status. Every field on it is either something a human set or something an agent recorded, and the second kind is what makes a factory traceable.

**Copy and paste**

```bash
cd "$ASCII_ART_PATH"
BEAD=$(bd list --status closed --limit 1 --json | jq -r '.[0].id')
bd show "$BEAD" --json | jq '.[0]'
```

| Field | What it is | Who sets it |
| --- | --- | --- |
| `id` | rig-prefixed identity, stable forever | `bd` |
| `title`, `description` | the ask, in prose | whoever created it |
| `status` | `open`, `in_progress`, `blocked`, `closed` | agents, as work moves |
| `assignee` | the session holding it now, empty when queued | claimed by the session itself |
| `issue_type`, `priority` | epic or task, and how urgent | whoever created it |
| `metadata` | arbitrary key/value the agents write verdicts into | agents |
| `notes` | append-only prose trail | agents and you |
| `created_at`, `started_at`, `updated_at` | the timeline | `bd` |
| `dependency_count`, `dependent_count` | what blocks this, what this blocks | dependency edges |

**The interesting one is `metadata`.** Look at what is in it:

```bash
bd show "$BEAD" --json | jq '.[0].metadata'
```

That is where the architect wrote `architect_approved`, where the PR flow recorded its branch and pull request, and where a bounce recorded its reason. **A bead is the audit trail**, and the reason the factory is debuggable at all is that agents write their reasoning onto the work rather than into a log that scrolls away.

Two commands worth keeping:

```bash
bd list --status blocked          # everything stuck, and why
bd show "$BEAD" --json | jq -r '.[0].notes'
```

### 3. Formula runs

A formula is the method; a *run* is one execution of it against one bead. **This is the one view the dashboard has and the CLI does not**, so it is the reason to keep a browser tab open.

In the browser, open a formula and read its runs: which steps ran, in what order, and where one stopped. Compare that against the `[[steps]]` graph you read in W4. A run that stopped early is a step whose `needs` were never satisfied, and the run view is where that becomes obvious rather than mysterious.

From the command line you get the recipe and the wreckage rather than the run itself:

**Copy and paste**

```bash
cd "$FACTORY_PATH"
gc formula list
gc formula show mol-polecat-pr          # the compiled recipe, steps and all
```

```bash
cd "$ASCII_ART_PATH"
bd show "$BEAD" --json | jq '.[0].metadata'   # what the steps recorded as they ran
```

A formula step writes its result onto the bead, so the metadata is the run's footprint even without the run view. Reach for the dashboard when you want the shape of the execution; reach for the bead when you want the outcome.

### 4. Agent sessions, live

**Copy and paste**

```bash
gc session list
gc session peek <a-running-session-id> --lines 30
gc session logs <a-running-session-id>
```

The dashboard has the same thing, streaming, so you can watch an agent work without a terminal.

Three commands, three different jobs, and they are easy to confuse:

- `peek` reads the last N lines without touching the session. Safe, and the right default.
- `logs` gives you the whole transcript after the fact, including for sessions that have exited.
- `attach` puts you inside the tmux session. Highest bandwidth, and the only one that can accidentally type into a running agent. `Ctrl-b` then `d` to leave.

Most pool sessions are ephemeral, so a session you saw a minute ago may be gone. That is correct behaviour rather than a fault: the session exits and its record stays on the bead.

### 5. The event log

Everything above is state. The event log is the sequence that produced it.

**Copy and paste**

```bash
gc events --since 1h
gc events --type bead.closed --since 1h
gc order history
```

**What to notice.** `bead.closed` is the event your `bead-closed-log` order is subscribed to. You can see the event that fired the order, then read the line the order wrote:

```bash
cat "$ASCII_ART_PATH/FACTORY_LOG.md"
```

That is the whole traceability chain in one screen: an agent closed a bead, the runtime emitted an event, an order was waiting on that event, and the order left an artifact. Every arrow in that sentence is separately inspectable, which is what "traceable" means in practice.

### 6. Reflect

The factory keeps three kinds of record and they answer different questions. **State** lives on the bead and answers "what is true now". **Events** are the ordered log and answer "what happened, in what order". **Sessions** are the transcript and answer "what was the agent actually thinking".

When something goes wrong, go in that order. State first, because it is cheapest and usually enough. Events second, when the question is about timing or about something that fired on its own. Sessions last, because they are the most detail and the least durable.

## Verification

**Copy and paste**

```bash
gc dashboard --no-open
bd list --status closed --limit 3
gc events --since 30m
gc order history
```

**Expected output**

```text
a http:// URL for the dashboard
at least one closed bead
a handful of recent events
at least one order run
```

## Troubleshooting

- **`gc dashboard` says it cannot resolve the supervisor URL.** The supervisor is not running. `gc status` from inside the city, then `gc start` if it reports stopped.
- **The dashboard opens but the beads list is empty.** You are looking at a different city or a different rig than the one holding your work. Check the city selector, and remember `factory1` and `ascii-art` have separate beads stores with different prefixes.
- **`gc session peek` reports no such session.** Ephemeral sessions exit when their work is done. Re-run `gc session list`; if nothing is live, sling a bead to spawn one.
- **`gc events` returns nothing for a type you expected.** Check the spelling against a broader `gc events --since 2h`; event types are dotted names such as `bead.closed`, and a near-miss returns a silent empty rather than an error.
- **On a cloud box the browser cannot reach the URL.** The dashboard is bound on the box, not on your laptop. Use `sfbox dashboard` to tunnel it.

## What's next

You have built a factory and learned to read it. [L1](./L1-plan-your-factory.md) turns the attention to your own project: what it is, and what a factory for it would need to do.

« [previous: W4 Tour the Factory](./W4-tour-the-factory.md) | [next: L1 Plan Your Factory](./L1-plan-your-factory.md) »
