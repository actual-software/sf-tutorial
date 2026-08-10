# L-5 · Work on Your Factory: Implement a Feature

« [previous: L-4 Self-improvement Loop](../hardening/05-self-improvement-loop.md) | [next: W-8 Sharing Your Factory](./10-sharing-your-factory.md) »

**Lab · Thursday 3:00–4:30 · 90 minutes · your own project**

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context: this block reads yesterday's output](#context-this-block-reads-yesterdays-output)
- [How the lab runs](#how-the-lab-runs)
- [Try It](#try-it)
  - [1. Re-read the map and pick one](#1-re-read-the-map-and-pick-one)
  - [2. Build it](#2-build-it)
  - [3. Prove it worked](#3-prove-it-worked)
  - [4. Put it behind a gate](#4-put-it-behind-a-gate)
  - [5. Take the next one, or go deeper](#5-take-the-next-one-or-go-deeper)
  - [6. Reflect](#6-reflect)
- [Deliverable](#deliverable)
- [Verification](#verification)
- [Ceiling](#ceiling)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

Take the capability map you wrote yesterday, build the change at the top of it, and prove it works on your own repository. This is the biggest and least scripted block of the two days.

## Prereqs

- [L-1](./07-plan-your-factory.md) complete, with `docs/current/capability-map.md` committed to your rig.
- [W-7](./08-mayor-and-workflows.md) complete, so the agent / formula / order split is familiar.
- [L-2](../hardening/02-specialize-reviewers-per-domain.md) complete: your gates run on your rig.

## Context: this block reads yesterday's output

Every other block in these two days starts from a clean line. This one starts from a document you wrote, and that is deliberate.

The reason is that a capability map written after a day of contact with your own repository is better than anything you would design in the abstract, and it is much better than a list of features someone else thinks your factory needs. Yesterday your gate bounced one of your beads and told you why. Yesterday a reviewer produced an opinion because it had nothing to cite. Those are findings, and the map is where you wrote them down before they faded.

Ninety minutes is enough to build one change properly, or two small ones. It is not enough for five. The ranking you did yesterday is what makes that survivable.

If the map has gone stale after a morning of labs, spend five minutes updating it before you build anything. A stale rank-1 is worse than no rank at all.

## How the lab runs

Ninety minutes, participant-led, no shared end state. The instructor circulates; say which layer you are working in when they reach you, because the failure modes are different in each and pairing works best within a layer.

## Try It

### 1. Re-read the map and pick one

**Copy and paste**

```bash
cd "$MY_RIG_PATH"
$EDITOR docs/current/capability-map.md
```

Re-rank if the morning changed your mind, then commit the re-rank before you build. A map with a stale ranking is a map you will stop trusting.

Then commit to one row out loud, to yourself or to whoever you are pairing with, in this shape:

> I am changing the **\<agent | formula | order\>** layer so that **\<the factory does X\>**, and I will know it worked when **\<the verification from the map's column\>**.

If you cannot fill that sentence in, the row is not ready and the second-ranked one probably is.

### 2. Build it

Where you work depends on the layer. Each has a worked example already in the repo to copy the shape from.

**Agent layer.** You are changing what an agent knows or how it judges. The files are a prompt template and an `agent.toml` under a pack's `agents/<name>/`. The closest example is the domain reviewers you retargeted this morning in [`hardening/02`](../hardening/02-specialize-reviewers-per-domain.md). Most agent-layer changes are prompt edits, and the highest-value edit is almost always giving a reviewer a real document to cite rather than more adjectives.

**Formula layer.** You are changing what steps a job has. The files are `*.formula.toml` under a pack's `formulas/`. The closest example is [`mol-polecat-pr`](../artifacts/packs/pr-gate-rig/formulas/mol-polecat-pr.formula.toml), which is worth copying specifically because it uses `extends` to replace exactly one step of a base formula and inherit the rest. Reach for `extends` before you write a formula from scratch; a short diff is easier to debug and it does not fork the base.

**Order layer.** You are changing when something happens. The file is an `order.toml` with one of four triggers. Use `condition` when the factory should react to its own bead store, `cooldown` or `cron` for a proactive sweep, and an exec order when the work is a script rather than agent work. `gc order show <name>` on any existing order gives you the shape.

Whichever layer, reload and check before you test:

```bash
cd "$FACTORY_PATH"
gc reload
gc doctor
```

### 3. Prove it worked

Run the verification you wrote in the map's own column. Not a different one that is easier to satisfy.

**Copy and paste**

```bash
cd "$MY_RIG_PATH"
bd create --title "<a bead that exercises the change>" --type task --priority 2
cd "$FACTORY_PATH"
gc sling project-manager <the-new-bead-id>
watch -n 5 'bd show <the-new-bead-id> --json | jq -r ".[0] | \"\(.status)  \(.assignee)\""'
```

The important part is the negative case. A gate you have only seen pass is a gate you have not tested. Construct the input that *should* be rejected and confirm it is:

```bash
bd create --title "<a bead your change should reject or catch>" --type task --priority 3
gc sling project-manager <that-bead-id>
bd show <that-bead-id> --json | jq -r '.[0] | .status, (.metadata.blocker_reason // "no blocker recorded")'
```

If both cases behave, the row is done. Mark it in the map and move on.

### 4. Put it behind a gate

A capability that can be skipped is a suggestion. If your change is a check, make it block; if it is a step, make something depend on it.

This is the same posture as the three governance requirements from [W-4](./02-first-review-loop.md): an unresolved blocking check has to prevent work from being marked ready, and the system has to fail visibly rather than proceeding quietly. Applied here it means one concrete thing — after your change, there is an input for which the factory stops and says why.

Confirm the failure is legible, not just present:

```bash
bd show <the-rejected-bead-id> --json | jq -r '.[0].metadata'
```

A blocker with no reason recorded is a stall rather than a gate. If the reason field is empty, that is your next edit.

### 5. Take the next one, or go deeper

With time left, you have a real choice, and the second option is usually worth more.

Take rank 2 and repeat, if it is genuinely independent of what you just built.

Or make what you just built survive someone else. Write the three sentences that explain it in your rig's docs, so tomorrow's version of you knows why the file exists. This is also most of the work for [W-8](./10-sharing-your-factory.md) in half an hour, which is about what travels when you hand a factory to a colleague.

### 6. Reflect

You have changed a factory on the basis of evidence it produced about itself. That loop, rather than any single change, is the thing worth taking home.

Two questions worth answering before the block ends. Which layer did the change land in, and was that the layer you predicted yesterday? And what did building it add to the map that was not there this morning?

Whatever the second answer is, write it into the map now. It is the first row of the next version of this exercise, and unlike today you will not have a room full of people to help you rediscover it.

## Deliverable

One capability-map row built, verified on both the positive and the negative case, and committed to your rig.

Two rows if they were independent and small. Not five.

## Verification

```bash
cd "$FACTORY_PATH"
gc doctor
gc reload
cd "$MY_RIG_PATH"
git log --oneline -5
bd list --status closed --limit 5
```

Expect a clean doctor, your change in the log, and at least one bead that went through the changed path.

## Ceiling

Break your own change on purpose, then make the breakage legible.

Feed it the input you least expected: an empty bead, a bead in a language your prompt does not mention, an order whose condition is true forever. What you are looking for is not whether it survives, but whether the failure says something useful. A factory that fails loudly is one you can leave running; a factory that fails quietly is one you have to watch.

## Troubleshooting

- **`gc reload` succeeds but the change has no effect.** The pack is imported at the wrong scope. A rig-scoped agent patched by a city-scoped pack does not compose; check which scope the pack declares and where it is imported.
- **The new order never fires.** Run `gc order check` to see whether it is even eligible, then run its `check` predicate by hand in a shell. A condition order with a predicate that errors is indistinguishable from one whose predicate is false.
- **The formula runs but skips your new step.** Steps declare dependencies with `needs`. A step nothing depends on, and which nothing lists as a need, is unreachable.
- **You are out of time and half done.** Commit what works and write the rest as map rows. A half-applied formula edit left in place will confuse you tomorrow far more than an unfinished row will.

## What's next

[W-8 Sharing Your Factory](./10-sharing-your-factory.md) closes the two days: what travels when you hand this to someone else, and what has to be scrubbed first.

« [previous: L-4 Self-improvement Loop](../hardening/05-self-improvement-loop.md) | [next: W-8 Sharing Your Factory](./10-sharing-your-factory.md) »
