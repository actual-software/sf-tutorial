# Specialized Domain Reviewers

## Contents

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

- [W3](../progression/W3-run-your-factory.md) complete: the base factory installed on a rig, with the polecat, refinery and architect running.
- You are inside the rig directory, with `$FACTORY_PATH`, `$ASCII_ART_PATH`, `$TUTORIAL_PATH` and `$ARTIFACTS_PATH` exported, then `cd "$ASCII_ART_PATH"`.
- `gh` is authenticated; `jq` is installed.
- An open task bead to work with. `bd list --status open --limit 5` picks one.

**This option needs no other option.** It installs on the base factory and ships all four reviewers plus the refinery patrol that fans out to them.

**Three of the four lanes defer without the [bead creation](./01-bead-creation-formula-extensions.md) option.** The design, testing and docs reviewers each read a spec that option's Leads write (`metadata.design_doc`, `test_plan`, `docs_outline`), and each is written to stamp its lane approved with a deferral note when that field is unset rather than block on it. So on the base factory alone this is a real ADR review plus three lanes that pass through. Installing both options is what turns the other three on, and that is by design: the Leads are the spec authors and these reviewers are not.

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

Copy the pack into the city's `packs/` directory.

**Copy and paste**

```bash
mkdir -p "$FACTORY_PATH/packs"

# Delete first: cp -r copies the source *into* the destination when the destination already exists, so a second run would nest the pack.
rm -rf "$FACTORY_PATH/packs/domain-reviewers-rig"

cp -r "$ARTIFACTS_PATH/packs/domain-reviewers-rig" \
      "$FACTORY_PATH/packs/domain-reviewers-rig"
```

Confirm the pack landed flat, with a single `pack.toml` at its top level:

**Copy and paste**

```bash
find "$FACTORY_PATH/packs/domain-reviewers-rig" -name pack.toml
```

**Expected output**

```text
$FACTORY_PATH/packs/domain-reviewers-rig/pack.toml
```

Register the new import at rig scope and remove the now-redundant
direct `bead-builders-rig` import.

**Copy and paste**

```bash
cd "$FACTORY_PATH"

gc import add --rig ascii-art "$ARTIFACTS_PATH/packs/domain-reviewers-rig"

# Nothing is removed. This option sits alongside the base factory,
# which keeps its orders and resolves the shared packs once.

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
  `gc import add --rig ascii-art packs/domain-reviewers-rig`
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

This is one of six options, and they are a menu rather than a sequence. Every one installs on the base factory alone, so take them in whatever order solves a problem you actually have. The full list is in [the feature labs](../progression/L3-L5-feature-labs.md#the-six-options).

Pairs naturally with the [bead creation Leads](./01-bead-creation-formula-extensions.md), which turn on the three lanes that otherwise defer, and with the [architecture best-practices loop](./03-architecture-best-practices-loop.md), which adds depth to whichever architecture lane you keep.

« [back to the feature labs](../progression/L3-L5-feature-labs.md) »
