# Specialize reviewers per domain

« [previous: W-7 The Mayor and Workflows](../progression/08-mayor-and-workflows.md) | [next: L-3 Hardening — Track A, scoring](./03-architecture-best-practices-loop.md) »

**Lab L-2 · Retargeting the Rig · Thursday 10:00–10:45 · 45 minutes · your own project**

## Block L-2: Retargeting the Rig

This page is both a standalone hardening exercise and the source material for lab L-2. Everything under this heading is the lab framing, which runs the walkthrough below against *your* rig instead of `ascii-art`. The walkthrough itself starts at [Objective](#objective).

### What the block is for

Take the gates you built yesterday on `ascii-art` and run them against your own repo, then split the single reviewer into reviewers that know something about your domains.

### Before the block starts

- [L-1](../progression/07-plan-your-factory.md) complete: your own repo registered as a rig, a project manifest committed, real beads in the queue.
- [W-4](../progression/02-first-review-loop.md) and [W-5](../progression/05.1-bead-gate-checks.md) complete on `ascii-art`, so you have a working reference for what you are about to move.
- `gh` authenticated against the org that owns your repo, with enough permission to set branch protection.

### What actually has to change

The walkthrough below installs the `domain-reviewers-rig` pack and replaces the single architect from W-4 with four reviewers running in parallel: ADR, design, testing and docs. The refinery fans out, waits for all four, aggregates the verdicts, and routes the bead.

It is written against `ascii-art`. Everywhere it says `ascii-art`, read "your rig". Three things do not translate by find-and-replace, and they are the whole lab.

**Your rig has different domains.** ADR, design, testing and docs are the four that make sense for a text-generation project. A backend service might want ADR, testing, security and data-migration. A mobile app might want design, accessibility, testing and release. Pick the four that would actually catch something on your codebase, and be willing to run three instead of four.

**Your reviewers need something to review against.** The ADR reviewer on `ascii-art` reads `docs/decision-records/` and `docs/current/`. If your repo has no decision records, the reviewer has nothing to cite and its verdict degrades to an opinion. Either point it at the documents you do have, or accept that this reviewer is weak until you write them.

**Your gates are only as good as your acceptance criteria.** The test-generation check from [W-5](../progression/05.1-bead-gate-checks.md) reads the bead and asks whether the described behaviour is testable. On `ascii-art` that is easy because the beads are precise. On your repo it will surface how loose your beads are, which is uncomfortable and is the useful part.

### How the lab runs

Fifteen minutes of demo, then thirty in which you do it. The instructor circulates; there is no shared end state to arrive at.

**Part 1, move yesterday's gates onto your rig.** Work in your own rig directory rather than `ascii-art`.

1. Install the packs your gates need, at rig scope on your rig rather than on `ascii-art`. That is the `review-loop-rig`, `architect-rig` and `bead-gate-rig` from W-4 and W-5.
2. Apply branch protection to your repo, using [`03`](../progression/03-branch-protection.md)'s script as the template. Adjust `CODEOWNERS` so it names people who actually exist in your org.
3. Sling one real bead and watch it go through. Do not pick your hardest bead. Pick one where you already know what the right answer looks like, so you can tell whether the factory got there.

Stop and look at the first verdict properly. On `ascii-art` the reviewers agreed with you because the project is simple. On your repo the first disagreement is information: either the reviewer is wrong and its prompt needs your domain knowledge, or it is right and your bead was vague.

**Part 2, split the reviewer by domain.** Now run the walkthrough below against your rig, with your four domains substituted for its four.

The pack ships four agent definitions under `artifacts/packs/domain-reviewers-rig/agents/`. Each is a prompt template plus an `agent.toml`. Renaming a reviewer is a two-file edit; giving it real domain knowledge is a prompt edit, and that is where your thirty minutes go.

Carry the test-generation gate across too. It was built in W-5 on the bead-gate mechanism, so it moves with the `bead-gate-rig` pack rather than with the reviewers, and it is the check most likely to fire on a real backlog.

### What you leave with

Your own rig, running your own beads, through gates you moved yourself: a required review round, a human merge, and reviewers that know something about your domains.

Note down every place where the `ascii-art` version worked and yours did not. That list is the raw material for [L-4](./05-self-improvement-loop.md) this afternoon.

Check the block landed:

```bash
gc rig show <your-rig>
bd list --status in_progress
gh pr list --repo <your-org>/<your-repo> --limit 5
```

Expect your rig to list the packs you installed, at least one bead in flight, and a pull request the factory opened rather than one you opened.

### If you fall behind in this block

There is no bootstrap argument for this lab, because the script rebuilds `ascii-art` and your rig is not `ascii-art`. If your own rig is in a state you cannot recover, fall back to running this page on `ascii-art` unchanged:

```bash
cd path/to/sf-tutorial/bootstrap
./bootstrap.sh 05.1-bead-gate-checks
```

Then work the walkthrough as written. You still learn the fan-out mechanics, and you can retarget after the workshop when nothing is on a clock.

### Ceiling

Make one reviewer genuinely expensive and prove it is worth it. Give a single domain reviewer a real specification to read, such as your API contract, your migration policy or your accessibility standard, and then sling a bead you know violates it. If the reviewer catches the violation and cites the document, you have a gate. If it produces a plausible paragraph that never names the document, you have a rubber stamp, and the fix is in the prompt rather than in the model.

### Block troubleshooting

- **The refinery fans out but never aggregates.** One lane never posted a verdict. `gc session list` shows which reviewer is still alive or has died; the refinery is waiting on it by design.
- **Every reviewer passes everything.** Usually the reviewers have no source documents to cite. Check that the paths in each `agent.toml` resolve inside *your* rig, not inside `ascii-art`.
- **Branch protection refuses to apply.** You need admin on the repo. If your org's repo is not yours to protect, fork it for the workshop and retarget the rig at the fork.

### Where the block goes next

[L-3 Hardening](./03-architecture-best-practices-loop.md) is the long lab, and you pick which of two directions to take.

---

The rest of this page is the walkthrough, written against `ascii-art`.

## Contents

- [Block L-2: Retargeting the Rig](#block-l-2-retargeting-the-rig)
- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context](#context)
- [Walkthrough](#walkthrough)
  - [1. Install the domain-reviewers-rig pack into factory1](#1-install-the-domain-reviewers-rig-pack-into-factory1)
  - [2. Pick the next bead and run it through H1's pre-PM agents](#2-pick-the-next-bead-and-run-it-through-h1s-pre-pm-agents)
  - [3. Watch the polecat work and hand the bead to the refinery](#3-watch-the-polecat-work-and-hand-the-bead-to-the-refinery)
  - [4. Watch the refinery fan out to four reviewers in parallel](#4-watch-the-refinery-fan-out-to-four-reviewers-in-parallel)
  - [5. Watch the refinery aggregate and proceed](#5-watch-the-refinery-aggregate-and-proceed)
  - [6. (Optional) Demonstrate single-lane rejection](#6-optional-demonstrate-single-lane-rejection)
  - [7. Reflect](#7-reflect)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

Install the `domain-reviewers-rig` pack into the `ascii-art` rig, replacing the single page-04 architect with four parallel domain reviewers (ADR, design, testing, docs) and watching the refinery fan out, aggregate verdicts, and route the bead.

## Prereqs

- Hardening 1 complete: `bead-builders-rig` is installed, the three
  Leads (Design / Test / Doc) are registered, and at least one bead
  has been through them so `metadata.design_doc`, `test_plan`,
  `docs_outline` are stamped.
- You're inside the rig directory. If a fresh shell, re-export
  `$FACTORY_PATH`, `$ASCII_ART_PATH`, `$TUTORIAL_PATH`, and
  `$ARTIFACTS_PATH` per
  [00.3](../progression/00.3-setup-foundation.md), then
  `cd "$ASCII_ART_PATH"`.
- `gh` is authenticated; `jq` is installed.
- Letters consumed so far: a–j. The next open task bead is
  `Implement k.md`.

## Context

Branching/Merging strategy is unchanged from page 04. What changes
here is the back of the factory: the single `architect` agent from
page 04 splits into **four parallel domain reviewers** — ADR,
design, testing, docs — that all run against the same polecat diff,
each citing its own doc family. The refinery waits for approvals
from all four lanes before letting a bead reach the inherited
`approval-review` and `merge-push` steps.

Agent workflow with the four reviewers in place:

1. The **operator** drafts the bead, runs the three Leads from H1,
   commits the spec files, and slings the project-manager. (Same
   front-of-factory flow as Hardening 1.)
1. The **polecat** writes the file and reassigns to the refinery.
   (Unchanged from pages 01–04.)
1. The **refinery's** first step on the patrol — `verify-reviewers`
   — reads four lane-verdict metadata fields:
   `adr_approved`, `design_approved`, `testing_approved`,
   `docs_approved`. On a fresh bead all four are unset, so the
   refinery uses `gc sling` to dispatch all four reviewers in
   parallel and drains.
1. The **four domain reviewers** run independently:
   - **`adr-reviewer`** reads `docs/decision-records/` and stamps
     `adr_approved` + `adr_feedback`.
   - **`design-reviewer`** reads `metadata.design_doc` (the H1
     design-lead's spec) and any `*DESIGN*` ADRs and stamps
     `design_approved` + `design_feedback`.
   - **`testing-reviewer`** reads `metadata.test_plan` and any
     `*TEST*` ADRs and stamps `testing_approved` +
     `testing_feedback`.
   - **`docs-reviewer`** reads `metadata.docs_outline` plus
     `README.md` and `docs/current/` and stamps `docs_approved` +
     `docs_feedback`.

   Each reviewer reassigns the bead to the refinery after stamping.
1. The **refinery** picks the bead up after all four have stamped.
   `verify-reviewers` reads the four verdicts and the cycle counter:
   - **All four = "true"**: single proceed gate fires; the patrol
     falls through to `approval-review` and `merge-push`.
   - **Any = "false"** under the cap (`review_loops < 2`):
     refinery increments `review_loops`, unsets all four
     `*_approved` flags, and bounces the bead to the polecat pool
     with all four `*_feedback` strings combined as the rejection
     reason.
   - **Any = "false"** at the cap (`review_loops >= 2`): refinery
     sets `review_cap_reached=true`, force-flips all four
     `*_approved=true`, mails the mayor with the combined feedback,
     and falls through to the inherited gates. The four
     `*_feedback` fields stay on the bead as the durable record of
     open concerns.
1. The **merger** (human, plus branch protection from page 03)
   reads the four review trails (and `review_cap_reached` /
   `*_feedback` if the cap fired) and clicks **Merge**.

The reviewers do **not** push code, count cycles, force-approve, or
close the bead. Each writes only its own lane's verdict. The
refinery owns flow-control and the cap.

You'll install the **domain-reviewers-rig** pack into the `ascii-art` rig
(removing `bead-builders-rig` from the rig's direct imports — the
new pack imports it transitively, so the Leads, project-manager,
and earlier agents remain available). Restart so the four new
reviewer agents and the new refinery patrol take effect. Sling the
next letter from `letters-a-m` through the H1 Leads, the
project-manager, and the polecat as before. Watch the refinery
fan out to all four reviewers, see four independent verdicts land
on the bead, then watch the refinery aggregate and proceed (or
bounce). Optionally craft a deliberate violation in one lane to
watch only that lane reject.

The next page (Hardening 3) adds review **depth** along the ADR
lane: per-principle scoring against 23 canonical architecture
principles with an append-only audit trail.

## Walkthrough

### 1. Install the domain-reviewers-rig pack into factory1

The page 04 architect was a single reviewer with a single corpus
(ADRs + `docs/current/`). H1 added three pre-PM Leads producing
design / test / docs specs per bead — but the post-PM review side
was still one agent reading everything. The natural next step is to
split the architect into four parallel lanes, each citing the doc
family it owns. ADR rule violations cite the ADR. Design-spec
violations cite the design spec the design-lead wrote. Test-plan
violations cite the test plan the test-lead wrote. Docs outline
violations cite the outline the doc-lead wrote.

This ships as a single rig-scoped pack, **`domain-reviewers-rig`**,
that supersedes `architect-rig`'s single architect:

- Four new rig-scoped reviewer agents (`adr-reviewer`,
  `design-reviewer`, `testing-reviewer`, `docs-reviewer`), each
  with `pool min=0, max=2` so two beads per lane can be reviewed in
  parallel without piling up sessions.
- Four new formulas (`mol-adr-review`, `mol-design-review`,
  `mol-testing-review`, `mol-docs-review`), each a 3-step
  load-context → review-and-record → drain pour.
- A new formula `mol-refinery-domain-patrol` that **extends**
  `mol-refinery-pr-patrol` (skipping the architect-rig's patrol
  entirely) and inserts a `verify-reviewers` step. The new step
  dispatches missing reviewers via `gc sling`, aggregates the four
  `*_approved` lane verdicts, and routes the bead.
- A `[[patches.agent]]` block that overrides the refinery prompt
  template to point at `mol-refinery-domain-patrol` instead of
  `mol-refinery-architect-patrol`.

The new pack declares one import: `bead-builders-rig` (which
transitively brings bead-gate-rig → architect-rig → pr-gate-rig →
setup). The single architect agent from architect-rig is no
longer wired into the refinery's flow — the refinery routes to the
four new reviewers instead. The architect agent itself is harmless
to leave loaded (it sits idle), but you can remove it from the rig
import chain if you want a leaner agent set.

The review-cycle cap is **2 rejections**, same as page 04.

Inspect the pack before installing.

**Copy and paste**

```bash
ls "$ARTIFACTS_PATH/packs/domain-reviewers-rig/"
cat "$ARTIFACTS_PATH/packs/domain-reviewers-rig/pack.toml"
ls "$ARTIFACTS_PATH/packs/domain-reviewers-rig/agents/"
cat "$ARTIFACTS_PATH/packs/domain-reviewers-rig/agents/adr-reviewer/agent.toml"
cat "$ARTIFACTS_PATH/packs/domain-reviewers-rig/agents/design-reviewer/agent.toml"
cat "$ARTIFACTS_PATH/packs/domain-reviewers-rig/formulas/mol-refinery-domain-patrol.formula.toml"
```

What to notice:

- **One reviewer per lane.** Each agent owns one
  `metadata.<lane>_approved` field; siblings stay in their lanes.
- **Defer-on-stub.** Each lane prompt has a defer branch — if the
  matching spec file is unset on the bead or missing on disk, the
  reviewer stamps `<lane>_approved=true` with a "deferred" note
  rather than blocking. (When all three Leads have run, this is a
  no-op.)
- **Refinery dispatches in parallel.** `verify-reviewers` slings
  all four lane formulas at once (well, one after another in
  succession, but the sessions run in parallel after that).
  Reviewers can stamp in any order; the refinery's next patrol
  reads whichever subset has finished.

Copy the pack into the city's pack directory.

**Copy and paste**

```bash
cp -r "$ARTIFACTS_PATH/packs/domain-reviewers-rig" \
      "$FACTORY_PATH/.gc/system/packs/domain-reviewers-rig"
```

Register the new import at rig scope and remove the now-redundant
direct `bead-builders-rig` import.

**Copy and paste**

```bash
cd "$FACTORY_PATH"

gc import add --rig ascii-art .gc/system/packs/domain-reviewers-rig
gc import remove --rig ascii-art bead-builders-rig
```

Verify.

The rig should now import `domain-reviewers-rig` and no longer import `bead-builders-rig`.

**Copy and paste**

```bash
gc import list --rig ascii-art
```

**Expected output**

```text
TBD: capture actual terminal output during smoke test
```

The city's imports are unchanged — `pr-gate-city` should still be there.

**Copy and paste**

```bash
gc import list
```

**Expected output**

```text
TBD: capture actual terminal output during smoke test
```

Restart.

**Copy and paste**

```bash
gc restart
```

Confirm the formulas and the new refinery patrol.

Five rows should be listed.

**Copy and paste**

```bash
gc formula list \
  | grep -E "mol-(adr|design|testing|docs)-review|mol-refinery-domain-patrol"
```

**Expected output**

```text
TBD: capture actual terminal output during smoke test
```

### 2. Pick the next bead and run it through H1's pre-PM agents

Same recipe as Hardening 1.

**Copy and paste**

```bash
cd "$ASCII_ART_PATH"
export BEAD_ID=$(bd list --type=task --status=open --limit 0 | grep -E "Implement k\.md$" | awk '{print $2}')

cd $FACTORY_PATH
# Run the three Leads (H1).
gc sling ascii-art/domain-reviewers-rig.design-lead $BEAD_ID --on mol-design-spec
gc sling ascii-art/domain-reviewers-rig.test-lead   $BEAD_ID --on mol-test-spec
gc sling ascii-art/domain-reviewers-rig.doc-lead    $BEAD_ID --on mol-doc-spec

cd $ASCII_ART_PATH
git add docs/design docs/testing docs/outlines
git commit -m "docs(specs): pre-PM specs for $BEAD_ID"
git push origin main

cd $FACTORY_PATH
gc sling ascii-art/domain-reviewers-rig.project-manager $BEAD_ID --on mol-bead-review
```

Wait for the project-manager to PASS the bead. The polecat will
pick it up next from the polecat pool.

### 3. Watch the polecat work and hand the bead to the refinery

Same play-by-play as pages 01–04. The polecat writes
`ascii/k.md`, pushes the branch, reassigns to the refinery.

### 4. Watch the refinery fan out to four reviewers in parallel

When the refinery picks the bead up, its `verify-reviewers` step
sees all four `*_approved` flags unset and slings all four
reviewers in succession. After draining, the refinery's session
ends; the four reviewer sessions run in parallel.

You should see four reviewer sessions plus the refinery (which may already have finished its current patrol).

**Copy and paste**

```bash
gc session list
```

**Expected output**

```text
TBD: capture actual terminal output during smoke test
```

Attach to any of the reviewer sessions to follow it.

**Copy and paste**

```bash
gc session attach <design-reviewer-session>
```

Watch the bead's metadata flip as each lane stamps a verdict.

**Copy and paste**

```bash
watch -n 5 'gc bd show $BEAD_ID | grep -E "_approved|_feedback"'
```

You should see the four `*_approved` fields appear one at a time,
each set to `true` (or `false` if a lane found a violation), each
with an accompanying `gc bd note` line.

### 5. Watch the refinery aggregate and proceed

When all four reviewers have stamped, the refinery picks the bead
up again. `verify-reviewers` reads the four verdicts; if all four
are `true`, the patrol falls through to `approval-review` and
`merge-push`.

**Copy and paste**

```bash
gc session list
gc session attach <refinery-session>
```

Poll until `pr_number` is populated.

**Copy and paste**

```bash
watch -n 5 'gc bd show $BEAD_ID'
```

Once the PR is up, merge as before.

**Copy and paste**

```bash
cd $ASCII_ART_PATH
export PR=$(BD_JSON_ENVELOPE=1 gc bd show $BEAD_ID --json | jq -r '.data[0].metadata.pr_number')
gh pr view "$PR" --web
gh pr merge "$PR" --merge
```

### 6. (Optional) Demonstrate single-lane rejection

To exercise the bounce path on just one lane, briefly add a strict
clause to one doc family that the polecat is likely to violate. For
example, edit the design spec the design-lead wrote for the next
bead (`l.md`).

**Copy and paste**

```bash
cd $ASCII_ART_PATH
export NEXT_BEAD_ID=$(bd list --type=task --status=open --limit 0 | grep -E "Implement l\.md$" | awk '{print $2}')

# Run the Leads first (so design-lead writes its spec).
cd $FACTORY_PATH
gc sling ascii-art/domain-reviewers-rig.design-lead $NEXT_BEAD_ID --on mol-design-spec
gc sling ascii-art/domain-reviewers-rig.test-lead   $NEXT_BEAD_ID --on mol-test-spec
gc sling ascii-art/domain-reviewers-rig.doc-lead    $NEXT_BEAD_ID --on mol-doc-spec

# Add a violating clause to the design spec.
echo "" >> $ASCII_ART_PATH/docs/design/$NEXT_BEAD_ID.md
echo "## Hard rule (testing this lane)" >> $ASCII_ART_PATH/docs/design/$NEXT_BEAD_ID.md
echo "Every letter file MUST include a 'Rendered by: <author>' line directly under the heading." >> $ASCII_ART_PATH/docs/design/$NEXT_BEAD_ID.md
git -C $ASCII_ART_PATH add docs/design && git -C $ASCII_ART_PATH commit -m "docs(specs): tighter design spec for $NEXT_BEAD_ID" && git -C $ASCII_ART_PATH push

gc sling ascii-art/domain-reviewers-rig.project-manager $NEXT_BEAD_ID --on mol-bead-review
```

The polecat won't include the "Rendered by" line (it's not in the
ADR or anywhere else the polecat checks). Watch the design-reviewer
post `design_approved=false` with `design_feedback` citing the
clause; meanwhile the other three lanes approve. The refinery's
`verify-reviewers` sees one rejection, increments `review_loops`,
and bounces the bead to the polecat pool with the combined feedback
(in this case, only the design lane's feedback is non-empty). The
polecat picks the bead up, addresses the feedback, hands back to
refinery; the cycle repeats up to 2 rejection rounds.

Roll the strict clause back when you're done so future letters
aren't blocked.

### 7. Reflect

That worked. Every PR is now reviewed across four axes — ADR,
design, testing, docs — by four independent agents, each citing the
doc family it owns. The refinery aggregates and decides; humans
see four short verdicts on the bead instead of one big "the
architecture says no" review. When a single lane finds a problem,
only that lane writes feedback; the others approve. When the
operator looks at a `review_cap_reached` bead, they read four
specific concerns rather than a generic "review exhausted" message.

What's still missing:

- **Reviews are binary per lane.** A lane is either approved or
  rejected; there's no notion of "approved with concerns about
  principles X and Y." **Hardening 3 — Architecture-best-practices
  loop** introduces a per-bead score against 23 canonical
  architecture principles with an append-only audit trail, so the
  rig accumulates locked architectural lessons over time.
- **One vendor.** Every reviewer (and the architect, project-manager,
  refinery, etc.) runs against the same model. **Hardening 4 —
  Strengthen the review system** stands up vendor-diverse reviewers
  (Codex / Claude / Gemini) plus a synthesizer that fuses three
  vendor verdicts into one.

## Verification

Confirm the cleared `$BEAD_ID` carries four lane verdicts.

**Copy and paste**

```bash
gc bd show $BEAD_ID | grep -E "_approved|_feedback"
```

**Expected output**

```text
adr_approved=true
design_approved=true
testing_approved=true
docs_approved=true
```

`*_feedback` may be unset on a clean bead.

Confirm the letter landed on `origin/main`.

**Copy and paste**

```bash
git fetch origin && git pull
ls ascii/k.md
```

## Troubleshooting

- **`gc formula list` doesn't show the four review formulas.**
  Pack didn't load. `gc import list --rig ascii-art` should show
  `domain-reviewers-rig`. If missing, re-run
  `gc import add --rig ascii-art .gc/system/packs/domain-reviewers-rig`
  and restart.
- **Refinery still says `Formula: mol-refinery-architect-patrol`.**
  The refinery prompt patch didn't apply. Confirm
  `domain-reviewers-rig` is imported at rig scope and that
  `architect-rig` is **not** also imported directly (two patches on
  the refinery's `prompt_template` will fight). Re-run
  `gc rig restart ascii-art` (or `gc restart`).
- **A reviewer rejects despite the spec being clean.** Read the
  reviewer's session log for which specific section it cited. Most
  often a too-strict reading of the spec — adjust the spec or
  refine the reviewer prompt to be more lenient on edge cases.
- **`design_approved=true` despite no design spec on the bead.** The
  design-reviewer's defer branch fired — `metadata.design_doc` was
  unset or pointed at a missing file. Run the Design Lead
  (Hardening 1) and re-sling the project-manager, or accept that
  this lane defers when there's nothing to review.
- **Refinery loops three or more times in a single bead.** The cap
  should bound at 2 rejections. Check `metadata.review_loops` after
  each bounce; if it's not incrementing, the refinery's
  `verify-reviewers` step is failing the increment write. Inspect
  the refinery session log.
- **`<coordinator>` mail bounces.** Substitute your operator handle
  (e.g., `mayor`).

## What's next

Continue to [Architecture-best-practices loop](./03-architecture-best-practices-loop.md).
H3 adds depth along the ADR lane: a per-bead append-only score
across 23 canonical architecture principles, iterated up to 3
cycles until aggregate hits 0.9 or the cap trips.

« [previous: W-7 The Mayor and Workflows](../progression/08-mayor-and-workflows.md) | [next: L-3 Hardening — Track A, scoring](./03-architecture-best-practices-loop.md) »
