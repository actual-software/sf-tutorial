# W-5 · Intro to Software Factories: Requirement Gates

« [previous: W-4 Review Loops](./W-4-review-loops.md) | [next: W-6 Coordination Channels](./W-6-coordination-channels.md) »

**Workshop · Wednesday 2:00–3:00 · 60 minutes · one shared example**

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context: the cheapest gate is the earliest one](#context-the-cheapest-gate-is-the-earliest-one)
- [How the hour runs](#how-the-hour-runs)
- [The three things this block carries](#the-three-things-this-block-carries)
- [Deliverable](#deliverable)
- [Verification](#verification)
- [If you fall behind](#if-you-fall-behind)
- [Ceiling](#ceiling)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

Put a gate at the *front* of the factory: a bead that is malformed or unverifiable never reaches an implementer. By the end of the hour you have blocked two beads for two different reasons, and you have seen the machinery that drafts the missing context automatically.

## Prereqs

- [W-4](./W-4-review-loops.md) complete: the review loop, branch protection and the architect reviewer all in place.
- The four env vars from [`00.3`](../progression/00.3-setup-foundation.md) exported, and you are in the rig directory.
- `gh` authenticated, `jq` installed.

## Context: the cheapest gate is the earliest one

W-4 put three checkpoints between an implementer and `main`. Every one of them fires *after* the code exists, which means every one of them costs a model call, a branch, and a round trip before it can tell you the work was wrong.

This hour moves a gate to the front. The `project-manager` agent reads the bead before any implementer is allowed to claim it, walks a short checklist, and either routes the bead onward or blocks it with feedback. Nothing has been written yet, so a rejection costs almost nothing.

The checklist has two kinds of check in it, and the distinction is the idea worth taking home.

**Completeness checks** ask whether the bead is *filled in*. Is the title meaningful, is there a description, is `target_file` set, does the parent epic exist? These are mechanical, and they catch the beads someone typed in a hurry.

**The test-generation check** asks whether the bead is *verifiable*. Could you write the test before the code? A bead can pass every completeness check and still fail this one, because "improve the rendering" is a perfectly well-formed sentence that names no outcome anyone can assert.

That second check is the one that earns its keep on a real backlog. `ascii-art`'s seeded beads are precise because someone wrote them to be teachable. Yours will say "handle errors better", and this is the gate that makes somebody answer "what would you check to confirm this is done?" before a factory spends an hour guessing.

## How the hour runs

One page, worked end to end, plus a read of the pack that automates the context the gate asks for.

| Minutes | What | Where |
| --- | --- | --- |
| 2:00–2:35 | Install the gate, pass a clean bead, block a malformed one, unblock and re-sling | [`05.1`](../progression/05.1-bead-gate-checks.md), Try It steps 1–5 |
| 2:35–2:50 | Block a well-formed but unverifiable bead, then fix the description rather than the code | [`05.1`](../progression/05.1-bead-gate-checks.md), Try It step 6 |
| 2:50–3:00 | Read how the three Leads draft the context the checklist wants | [`hardening/01`](../hardening/01-bead-creation-formula-extensions.md), Context and Setup sections |

Step 6 is the new material and it is the part to protect if the hour runs tight. Steps 1 to 5 are the mechanism; step 6 is the reason the mechanism matters.

## The three things this block carries

The gameplan folds a third page into this hour, so W-5 is carrying more than its neighbours. Keeping the three straight is easier than it looks, because each one answers a different question.

1. **The front gate** ([`05.1`](../progression/05.1-bead-gate-checks.md), steps 1–5). *Is this bead complete enough to act on?* A `project-manager` agent, a checklist, and a blocked status the implementer pool ignores.
2. **The test-generation check** ([`05.1`](../progression/05.1-bead-gate-checks.md), step 6). *Is this bead verifiable?* The same agent and the same mechanism, one more check on the list. No new pack.
3. **The Leads that draft the context** ([`hardening/01`](../hardening/01-bead-creation-formula-extensions.md)). *Who fills in what the gate keeps asking for?* Three helper agents — design, test and docs — that read the rig's own documents and write a focused spec onto each bead before the gate sees it.

The third is worth reading even if you do not install it today. It is the answer to the objection this hour always produces: if the gate keeps rejecting my beads, am I now doing more work than before? The Leads are how a factory answers that question with automation instead of discipline.

## Deliverable

A factory whose front door rejects two different kinds of bad work, and one bead you fixed by editing its description rather than its code.

## Verification

```bash
cd "$ASCII_ART_PATH"
bd list --status blocked
bd show "$VAGUE_BEAD" --json | jq -r '.[0] | .status, .metadata.bead_review_passed'
```

Expect at least one bead that reached `blocked` and came back to `open` with `bead_review_passed=true` after you rewrote its description.

## If you fall behind

```bash
cd path/to/sf-tutorial/bootstrap
./bootstrap.sh 05.1-bead-gate-checks
```

That is this block's end state for steps 1 to 5. Step 6 creates its own bead, so you can run it immediately afterwards.

## Ceiling

Turn the test-generation check on your own backlog before tomorrow.

Take three real bead titles from whatever tracker you actually use, write them into `ascii-art` as beads with honest descriptions, and sling them at the gate. The verdicts are a free audit of how your team writes work, and whatever the gate objects to is a row for the capability map you write in [L-1](./L-1-plan-your-factory.md) in two hours.

If you would rather go deeper on the mechanism, open the `project-manager` prompt at `artifacts/packs/bead-gate-rig/agents/project-manager/prompt.template.md` and read the checklist as a document rather than as code. Every check is a sentence someone chose to write. Add one of your own and watch it fire.

## Troubleshooting

- **The gate passes a bead you expected it to block.** Check that `bead_review_passed` is not still `true` from an earlier pass; the agent no-ops when it is already stamped. Clear it with `bd update <bead> --unset-metadata bead_review_passed`.
- **`gc sling` reports the target is unknown.** The project-manager is namespaced by its pack. The full target is `ascii-art/bead-gate-rig.project-manager`, and the pack has to be imported at rig scope.
- **The bead blocks but no mail arrives.** The gate mails the mayor on failure. Read it with `gc mail inbox mayor` rather than a bare `gc mail inbox`, which defaults to your own inbox.
- **`hardening/01` says the checklist is extended, and it is not.** That page describes an extension to the project-manager's checklist that the pack does not currently ship. The three Leads and their formulas work as written; only the automatic enforcement is missing. Read the page for the Leads and treat the enforcement as the thing you would add.

## What's next

Gates decide whether work may start and whether it may finish. [W-6 Coordination Channels](./W-6-coordination-channels.md) is about how it moves in between.

« [previous: W-4 Review Loops](./W-4-review-loops.md) | [next: W-6 Coordination Channels](./W-6-coordination-channels.md) »
