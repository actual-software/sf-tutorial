# Architect Agent

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context](#context)
- [Setup](#setup)
  - [Bootstrap Factory1 with Script](#bootstrap-factory1-with-script)
  - [Build Factory1 by Hand](#build-factory1-by-hand)
    - [1. Install the architect-rig pack into factory1](#1-install-the-architect-rig-pack-into-factory1)
- [Try It](#try-it)
  - [1. Locate one bead from the first epic](#1-locate-one-bead-from-the-first-epic)
  - [2. Sling the bead to the polecat (PR mode)](#2-sling-the-bead-to-the-polecat-pr-mode)
  - [3. Watch the polecat work and hand the bead to the refinery](#3-watch-the-polecat-work-and-hand-the-bead-to-the-refinery)
  - [4. Watch the refinery hand the bead to the architect](#4-watch-the-refinery-hand-the-bead-to-the-architect)
  - [5. Watch the architect read the docs and post a verdict](#5-watch-the-architect-read-the-docs-and-post-a-verdict)
  - [6. Watch the refinery clear the gate and publish a PR](#6-watch-the-refinery-clear-the-gate-and-publish-a-pr)
  - [7. Manually approve and merge the PR](#7-manually-approve-and-merge-the-pr)
  - [8. (Optional) Sling a bead the architect will reject](#8-optional-sling-a-bead-the-architect-will-reject)
  - [9. Reflect](#9-reflect)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

By the end of this exercise you will have an architecture-aware `architect` agent installed between the polecat and the refinery, with every bead reviewed against the rig's ADRs and current architecture docs before any merge gate runs.

## Prereqs

- Page [the branch-protection appendix](./03-branch-protection.md) complete: branch protection on
  `main` is live, the `epic/*` ruleset is active, `.github/CODEOWNERS`
  is on `main` with your handle, and `f.md` merged through the gate.
- You're inside the rig directory. If you opened a fresh shell,
  re-export `$SOFTWARE_FACTORY_INTENSIVE_PATH` per
  [W2 Cloud Box and Preflight](../progression/W2-cloud-box-and-preflight.md), then
  `cd "$SOFTWARE_FACTORY_INTENSIVE_PATH/ascii-art"`.
- `gh` is authenticated and can create PRs against the rig's GitHub
  repo. Verify with `gh auth status` and `gh repo view`.
- `jq` is installed (the new formulas use it).
- The rig has at least one ADR under `docs/decision-records/` (page
  00 placed `0001.ADR.ASCII.md` there). The `docs/current/` directory
  may be empty initially — the architect tolerates that and just
  walks whatever is present.
- `STATUS_CHECKS=""` in your branch protection — required CI is wired
  in Hardening 1.

## Context

Branching/merging strategy is unchanged from branch protection. What changes
here is that every bead now passes through a dedicated `architect`
agent — sitting between the polecat and the refinery — that reads
the rig's locked architecture decisions and current architecture docs
and writes a verdict on the bead before the refinery is allowed to
proceed.

Agent workflow with the architect in place:

1. The **coder** (polecat) claims a bead and implements as before.
   When the polecat believes the work is done, it pushes its branch
   and reassigns the bead to the refinery.
1. The **refinery's** first step on the patrol — `verify-architect` —
   reads `metadata.architect_approved`. On a fresh bead it is unset,
   so the refinery reassigns the bead to the architect and drains.
   The refinery does not review the diff itself in this step.
1. The **architect** (new) reads the polecat's branch diff against
   the rig's ADRs (`docs/decision-records/`) and current architecture
   docs (`docs/current/`). It writes a verdict back onto the bead
   (`architect_approved=true|false`, plus `architect_feedback` on
   rejection) and reassigns the bead to the refinery. The architect
   never counts cycles or force-approves — it just reads and writes
   its honest verdict.
1. The **refinery** picks the bead up again. `verify-architect` reads
   the verdict and owns the cycle cap. The step has a **single
   proceed gate**: any time `architect_approved=true`, the patrol
   continues to `approval-review` and `merge-push`.
   - **Rejected** under the cap (`architect_approved=false`,
     `review_loops < 2`): the refinery increments `review_loops` and
     bounces the bead to the polecat pool with `architect_feedback`
     carried as the rejection reason. It also unsets
     `architect_approved` so the next refinery patrol re-routes the
     bead through the architect for re-review.
   - **Rejected** at the cap (`architect_approved=false`,
     `review_loops >= 2`): the refinery sets
     `review_cap_reached=true`, force-flips `architect_approved` to
     `true`, leaves `architect_feedback` intact for the operator and
     the inherited approval gate, and mails the mayor. The forced
     flip immediately satisfies the proceed gate — the same patrol
     falls through to `approval-review` and `merge-push`.
   - **Approved** (`architect_approved=true`, whether the architect's
     own verdict or the cap-forced flip): the step is a no-op and the
     inherited `approval-review` and `merge-push` steps run as in
     the review loop — refinery does its mechanical sanity checks, publishes
     a PR.
1. The **merger** (human, plus branch protection from branch protection) reads
   the architect's verdict trail (and `review_cap_reached` /
   `architect_feedback` if the cap fired), the inherited approval,
   and clicks **Merge** as before.

The architect does **not** push code, merge the PR, count cycles,
force-approve, or close the bead. It is a read + verdict-write agent.

In this exercise you will install the **architect-rig** pack into the
`ascii-art` rig (and remove `review-loop-rig` from the rig's direct
imports — the new pack supersedes it; the architect now owns the
review-loop concept, not the refinery). Restart so the new architect
agent and the patched refinery patrol take effect. Sling the next
letter from `letters-a-m` at the polecat exactly the way branch protection
taught you, then watch the refinery hand the bead off to the
architect, watch the architect post a verdict, and watch the refinery
proceed (or bounce back to the polecat pool, depending on the
verdict). Manually merge the resulting PR. Reflect on what just
happened: every bead now passes through an architecture review against
the full ADR + current docs corpus before any merge gate runs.

The next page closes the last upstream hole — bead malformation that
gets caught only after the polecat has already done work.

## Setup

This lesson has two paths to the same end state. Pick one.

### Bootstrap Factory1 with Script

If this is your first run, complete the one-time setup in the [bootstrap README](../bootstrap/README.md) (`.env`, `deps.sh`) before invoking the script.

**Copy and paste**

```bash
cd path/to/sf-tutorial/bootstrap
./bootstrap.sh 04-adr-reviewer
```

The script reproduces every step up through this lesson — `architect-rig` is added at rig scope, `review-loop-rig` is removed from the rig's direct imports (still resolved transitively via `architect-rig`), and the city is restarted.

After it finishes, re-export the four env vars per [W3 Run Your Factory](../progression/W3-run-your-factory.md), then jump to [Try It](#try-it).

### Build Factory1 by Hand

### 1. Install the architect-rig pack into factory1

The review loop setup gave the refinery a single hard-coded round of
self-generated feedback. The branch protection setup gated PRs on a CODEOWNER
approval. Neither one knows about the rig's ADRs or current
architecture docs — feedback was whatever the refinery thought of in
the moment, and CODEOWNERS only enforces "a human looked", not "a
human checked the architecture." We want a substantive
architecture-aware review on every bead, before any merge gate runs.

This ships as a single rig-scoped pack, **`architect-rig`**, that
supersedes `review-loop-rig`:

- A new rig-scoped agent `architect` (`scope = "rig"`, pool
  `min=0, max=2`) so two beads can be reviewed in parallel without
  piling up sessions. The agent's prompt teaches it to read every
  ADR under `docs/decision-records/` and every page under
  `docs/current/`, walk the diff against them, and post a verdict
  citing the failing doc — no lecturing.
- A new formula `mol-architect-review` poured by the architect on
  each assigned bead. Reads the diff, walks the docs, writes
  `architect_approved=true|false` (and `architect_feedback` on
  rejection), and reassigns the bead to the refinery. The architect
  does **not** touch `review_loops` or any cap — it writes only its
  verdict.
- A new formula `mol-refinery-architect-patrol` that **extends**
  `mol-refinery-pr-patrol` (skipping the review-loop pack entirely)
  and inserts a `verify-architect` step between `handle-failures` and
  `approval-review`. The new step does flow-control plus cycle-cap
  enforcement, with **a single proceed gate**: any time
  `architect_approved=true` — whether the architect wrote it or the
  refinery force-flipped it at the cap — the patrol falls through to
  `approval-review` and `merge-push`.
  - if `architect_approved` is unset, route the bead to the
    architect and drain;
  - if `architect_approved=false` and `review_loops < 2`, increment
    `review_loops` and bounce to the polecat pool with
    `architect_feedback` as the rejection reason;
  - if `architect_approved=false` and `review_loops >= 2`, mark
    `review_cap_reached=true` and force `architect_approved=true`,
    mail the mayor, and **fall through** into the proceed gate in
    the same step (no separate exit branch);
  - if `architect_approved=true`, no-op and let
    `approval-review`/`merge-push` run as inherited.
- A `[[patches.agent]]` block that overrides the refinery's prompt
  template — pointing the rig refinery at
  `mol-refinery-architect-patrol` instead of
  `mol-refinery-review-loop-patrol` on next start.

The new pack declares one import: `pr-gate-rig` (so the new patrol
formula can `extends = ["mol-refinery-pr-patrol"]`, and so `setup`
is reachable transitively for the refinery agent patch). It does
**not** import `review-loop-rig` — the review-loop concept has moved
into the architect, not the refinery, so that pack is superseded.
`pr-gate-city` (the pack that supplies the mayor) stays in place at city scope. Its
dispatch guidance (`gc sling <rig>/polecat <bead> --on
mol-polecat-pr`) is unchanged — the polecat still hands work to the
refinery; the refinery now hands it to the architect.

The review-cycle cap is **2 rejections** (up from the review loop's hard-coded
1 round). After two architect rejections, the next refinery patrol
sees the third rejection, marks `review_cap_reached=true`, forces
`architect_approved=true` for flow-control, mails the mayor, and lets
the inherited gates run. The cap lives in the **refinery's**
patrol formula, not the architect — the architect just writes
verdicts; the refinery counts and decides when to stop asking.

Inspect the pack before installing:

**Copy and paste**

```bash
ls "$SOFTWARE_FACTORY_INTENSIVE_PATH/sf-tutorial/artifacts/packs/architect-rig/"
cat "$SOFTWARE_FACTORY_INTENSIVE_PATH/sf-tutorial/artifacts/packs/architect-rig/pack.toml"
cat "$SOFTWARE_FACTORY_INTENSIVE_PATH/sf-tutorial/artifacts/packs/architect-rig/agents/architect/agent.toml"
cat "$SOFTWARE_FACTORY_INTENSIVE_PATH/sf-tutorial/artifacts/packs/architect-rig/agents/architect/prompt.template.md"
cat "$SOFTWARE_FACTORY_INTENSIVE_PATH/sf-tutorial/artifacts/packs/architect-rig/formulas/mol-architect-review.formula.toml"
cat "$SOFTWARE_FACTORY_INTENSIVE_PATH/sf-tutorial/artifacts/packs/architect-rig/formulas/mol-refinery-architect-patrol.formula.toml"
```

You should see `pack.toml`, an `agents/architect/` directory with
`agent.toml` and `prompt.template.md`, a `formulas/` directory with
two `.formula.toml` files, and a `prompts/` directory with the
patched refinery template.

What to notice in the pack:

- **One architect per rig.** `agent.toml` declares `scope = "rig"`
  with a pool of `min=0, max=2`.
- **Two doc trees, not one.** The architect prompt and formula both
  walk `docs/decision-records/` and `docs/current/` — ADRs are
  binding, current-arch docs are context.
- **Refinery is flow-control plus cap-enforcer, not reviewer.** The
  new `verify-architect` step reads `architect_approved`, increments
  `review_loops` on rejection, and decides whether to bounce or
  force-forward; it does not read the diff itself. The inherited
  `approval-review` step is unchanged.
- **Cap = 2 rejections, owned by the refinery.** The architect
  writes only its verdict. The refinery counts rejections, bounces
  while under the cap, and force-forwards once the cap is reached.

Copy the pack into the city's `packs/` directory:

**Copy and paste**

```bash
mkdir -p "$SOFTWARE_FACTORY_INTENSIVE_PATH/factory1/packs"

# Delete first: cp -r copies the source *into* the destination when the destination already exists, so a second run would nest the pack.
rm -rf "$SOFTWARE_FACTORY_INTENSIVE_PATH/factory1/packs/architect-rig"

cp -r "$SOFTWARE_FACTORY_INTENSIVE_PATH/sf-tutorial/artifacts/packs/architect-rig" \
      "$SOFTWARE_FACTORY_INTENSIVE_PATH/factory1/packs/architect-rig"
```

Confirm the pack landed flat, with a single `pack.toml` at its top level:

**Copy and paste**

```bash
find "$SOFTWARE_FACTORY_INTENSIVE_PATH/factory1/packs/architect-rig" -name pack.toml
```

**Expected output**

```text
$SOFTWARE_FACTORY_INTENSIVE_PATH/factory1/packs/architect-rig/pack.toml
```

Now register the new import at rig scope and remove the now-superseded
`review-loop-rig` import. Run from the city directory:

**Copy and paste**

```bash
cd "$SOFTWARE_FACTORY_INTENSIVE_PATH/factory1"

# Add the new pack at rig scope.
gc import add --rig ascii-art packs/architect-rig

# Remove review-loop-rig from the rig's direct imports.
# architect-rig replaces it — the review loop now lives in the
# architect, not the refinery — and architect-rig brings pr-gate-rig
# (and setup) along transitively.
gc import remove --rig ascii-art review-loop-rig
```

Verify the rig now imports `architect-rig` and not `review-loop-rig`:

The rig should now import `architect-rig` and no longer import `review-loop-rig`.

**Copy and paste**

```bash
gc import list --rig ascii-art
```

**Expected output**

```text
architect-rig	packs/architect-rig		(path)
```

The city's imports are unchanged — `pr-gate-city` should still be there.

**Copy and paste**

```bash
gc import list
```

**Expected output**

```text
pr-gate-city	packs/pr-gate-city		(path)
```

Restart the city so the new agent, formulas, and refinery prompt take
effect:

**Copy and paste**

```bash
gc restart
```

Confirm everything loaded:

All three formulas should be listed. `mol-polecat-pr` resolves transitively via `pr-gate-rig`; the two architect formulas are new with this pack.

**Copy and paste**

```bash
gc formula list | grep -E "mol-architect-review|mol-refinery-architect-patrol|mol-polecat-pr"
```

**Expected output**

```text
mol-architect-review
mol-polecat-pr
mol-refinery-architect-patrol
```

## Try It

### 1. Locate one bead from the first epic

Letters a–f have merged through pages 01–03. List the remaining open
`Implement <letter>.md` tasks and grab the next one:

**Copy and paste**

```bash
cd "$SOFTWARE_FACTORY_INTENSIVE_PATH/ascii-art"
bd list --type=task --status=open --limit 0 | grep "Implement [g-i]\.md"
```

Pick `g.md` and capture its ID:

**Copy and paste**

```bash
export BEAD_ID=$(bd list --type=task --status=open --limit 0 | grep -E "Implement g\.md$" | awk '{print $2}')
bd show $BEAD_ID
```

You should see `metadata.target_file=ascii/g.md` and no
`architect_approved` or `review_loops` field yet — the architect will
write `architect_approved` during its first review pass; the refinery
writes `review_loops` only on rejection-bounce.

### 2. Sling the bead to the polecat (PR mode)

Same dispatch recipe as pages 01–03. The architect is reached by
reassignment from the refinery, not by a new dispatch verb:

**Copy and paste**

```bash
cd $SOFTWARE_FACTORY_INTENSIVE_PATH/factory1
gc sling ascii-art/architect-rig.polecat $BEAD_ID --on mol-polecat-pr
```

When this works, you should see the task sent to the polecat along
with the formula:

**Expected output**

```text
⎿  Auto-convoy aa-0s7
    Attached wisp aa-3ii (formula "mol-polecat-pr") to aa-ne 1
    Slung aa-nel.1 (with formula "mol-polecat-pr") → ascii-art/architect-rig.polecat
```

### 3. Watch the polecat work and hand the bead to the refinery

In another terminal, list the live agent sessions:

**Copy and paste**

```bash
gc session list
```

Watch the polecat write the file and reassign to the refinery — same
play-by-play as the review loop up to the point where the polecat hands off.

**Copy and paste**

```bash
gc session attach <polecat-session>
```

Once the polecat finishes, the bead transitions to the refinery:

**Expected output**

```text
○ aa-7ln.13 · Implement g.md   [● P2 · OPEN]
Owner: Austin Born · Assignee: ascii-art/architect-rig.refinery · Type: task

NOTES
Implemented: ascii/g.md — symmetric G with serif terminals.

METADATA
  branch: gc-architect-rig.furiosa-k-282324
  gc.routed_to: ascii-art/architect-rig.refinery
  merge_strategy: pr
  target: main
  target_file: ascii/g.md
  work_dir: ...
```

### 4. Watch the refinery hand the bead to the architect

When the refinery picks the bead up, its first step
(`verify-architect`) sees `architect_approved` is unset and reassigns
the bead to the architect. No diff read, no rebase yet — the
refinery just routes.

**Copy and paste**

```bash
gc session list
gc session attach <refinery-session>
```

Once the refinery hands off, the bead's metadata flips:

**Expected output**

```text
METADATA
  ...
  gc.routed_to: ascii-art/architect-rig.architect
  ...
```

The bead's notes will pick up a line like
`verify-architect: routing to architect for review (loop 0).`

### 5. Watch the architect read the docs and post a verdict

The architect picks the bead up next. Its `mol-architect-review`
formula walks `docs/decision-records/` and `docs/current/`, reads the
branch diff, and writes a verdict.

**Copy and paste**

```bash
gc session list
gc session attach <architect-session>
```

When the architect finishes, the bead carries a verdict and is back
on the refinery:

**Expected output**

```text
○ aa-7ln.13 · Implement g.md   [● P2 · OPEN]
Assignee: ascii-art/architect-rig.refinery · Type: task

NOTES
architect: APPROVED. Diff is consistent with 0001.ADR.ASCII.md and
docs/current/.

METADATA
  architect_approved: true
  branch: gc-architect-rig.furiosa-k-282324
  gc.routed_to: ascii-art/architect-rig.refinery
  merge_strategy: pr
  target: main
  target_file: ascii/g.md
  ...
```

If the architect rejected the bead instead, you would see
`architect_approved: false` and `architect_feedback: <reason>` —
without any `review_loops` change yet. On the next refinery patrol,
`verify-architect` would bump `review_loops` to `1` (or `2` on a
later rejection), unset `architect_approved`, and bounce the bead to
the polecat pool with the feedback.

### 6. Watch the refinery clear the gate and publish a PR

The refinery picks the bead up a second time. `verify-architect`
sees `architect_approved=true` and falls through to the inherited
`approval-review` and `merge-push` steps from `mol-refinery-pr-patrol`.

**Copy and paste**

```bash
gc session attach <refinery-session>
```

Poll the bead until `pr_number` is populated:

**Copy and paste**

```bash
# If you have watch installed:
watch -n 5 'gc bd show $BEAD_ID'

# If you don't have watch installed:
while true; do clear; gc bd show $BEAD_ID; sleep 5; done

# Ctrl-C once metadata.pr_number is set.
```

You should see `refinery_approved: true`, `refinery_approval_at`, and
`pr_url` / `pr_number` populated, in that order.

### 7. Manually approve and merge the PR

The architect has done its job. Now do what branch protection already taught
you — approve as the CODEOWNER (or have a teammate approve), then
merge:

**Copy and paste**

```bash
cd $SOFTWARE_FACTORY_INTENSIVE_PATH/ascii-art
export PR=$(BD_JSON_ENVELOPE=1 gc bd show $BEAD_ID --json | jq -r '.data[0].metadata.pr_number')
gh pr view "$PR" --web
```

After approval, merge through the GitHub UI or:

**Copy and paste**

```bash
gh pr merge "$PR" --merge
```

Confirm the merge landed:

**Copy and paste**

```bash
git fetch origin && git pull
git log --oneline origin/main -1
ls ascii/g.md
```

### 8. (Optional) Sling a bead the architect will reject

To exercise the rejection path, briefly add a strict ADR clause that
the polecat is likely to violate, then sling another letter. For
example, edit `docs/decision-records/0001.ADR.ASCII.md` on `main` to
add a rule like:

> ASCII art rule 4: every letter file must include a `> Rendered by:
> <author>` line directly under the heading.

Commit and push to `main`. Then sling `h.md`:

**Copy and paste**

```bash
cd $SOFTWARE_FACTORY_INTENSIVE_PATH/ascii-art
export BEAD_ID=$(bd list --type=task --status=open --limit 0 | grep -E "Implement h\.md$" | awk '{print $2}')
cd $SOFTWARE_FACTORY_INTENSIVE_PATH/factory1
gc sling ascii-art/architect-rig.polecat $BEAD_ID --on mol-polecat-pr
```

Watch the architect post `architect: REJECTED. <feedback>` (no loop
counter from the architect — that's the refinery's job), then watch
the refinery bump `review_loops` to `1` and bounce the bead back to
the polecat pool with `architect_feedback` as the rejection reason.
The polecat picks the bead back up, addresses the feedback (or
stamps the new "Rendered by" line), reassigns to the refinery, the
refinery routes back through the architect, and the cycle continues
until either the architect approves or the refinery's cap
(2 rejections) trips.

If you trip the cap, you'll see `review_cap_reached: true` on the
bead, `architect_approved` force-flipped to `true` by the refinery
(satisfying the single proceed gate within the same patrol),
`architect_feedback` preserved with the architect's last concern,
and a mail to the mayor. The bead still has to clear the refinery's
inherited `approval-review` step before any PR is published — the
forced flag just keeps `verify-architect` from looping; it doesn't
skip the merge gate.

Roll the strict ADR clause back when you're done so future letters
aren't blocked.

### 9. Reflect

That worked. Another letter reached `main`, but the path was
substantively different from pages 01–03: every bead passed through
an architect that read the full ADR corpus and the current
architecture docs and wrote a verdict, before any merge gate ran.
The refinery is no longer a self-feedback loop or a single-shot
gate — it's a flow-controller that dispatches review work to a
specialist agent and proceeds only when that specialist has cleared
the bead.

What's still missing:

- **The architect runs *after* the polecat has written code.** If
  the bead description was malformed — wrong title, missing
  `target_file`, requirements that contradict the ADR before any
  code is written — the polecat still wastes a pass. **Page 05 —
  Bead review gate** adds a pre-implementation reviewer
  (`bead-reviewer`) that checks each bead is well-formed *before*
  the polecat starts.
- **One architect with one ADR + docs corpus.** No separate testing,
  design, or docs lens; no second-opinion review from an independent
  model. **Hardening 2 — Specialize reviewers** splits the review
  into per-domain reviewers (design, testing, docs).
- **One vendor.** **Hardening 4 — Strengthen review system** fans
  out to multiple vendor-diverse architects plus a synthesizer, and
  also raises the cap from 2 into a configurable budget.
- **Forced approvals are advisory.** When the cap trips, the
  architect mails the mayor and the bead proceeds with open
  concerns. There is no automated routing to a human reviewer for
  cap-tripped beads beyond that mail. Hardening 4 wires the operator
  decision into the dispatch loop.

## Verification

Confirm the new formulas are loaded:

**Copy and paste**

```bash
gc formula list | grep -E "mol-architect-review|mol-refinery-architect-patrol|mol-polecat-pr"
```

**Expected output**

```text
mol-architect-review
mol-polecat-pr
mol-refinery-architect-patrol
```

Confirm the cleared `g.md` bead carries an architect verdict:

**Copy and paste**

```bash
gc bd show $BEAD_ID
```

Expect `metadata.architect_approved=true`, an `architect: APPROVED...`
note, and (after merge) `pr_url` + `pr_number` populated.

Confirm the new letter on `origin/main`:

**Copy and paste**

```bash
cd $SOFTWARE_FACTORY_INTENSIVE_PATH/ascii-art
git fetch origin && git pull
git log --oneline origin/main -1
ls ascii/g.md
```

Expect a new merge commit referencing `Implement g.md` and the file
present.

Confirm worktrees are cleaned up:

**Copy and paste**

```bash
git worktree list
```

Expect a single line for the rig's main checkout.

## Troubleshooting

- **`gc formula list` doesn't show `mol-architect-review` or
  `mol-refinery-architect-patrol`.** The architect-rig pack didn't
  load. Run `gc import list --rig ascii-art` and confirm you see
  `architect-rig`. If it's missing, re-run
  `gc import add --rig ascii-art packs/architect-rig` and
  restart.
- **`gc import remove --rig ascii-art review-loop-rig` errors with
  "still in use" or similar.** Some installations may complain
  because of cached transitive references. The dependency is fine to
  remove because `architect-rig` extends `mol-refinery-pr-patrol`
  directly, not `mol-refinery-review-loop-patrol`. If `gc import
  remove` refuses, leave `review-loop-rig` in the rig's imports —
  `architect-rig`'s prompt patch and patrol formula will still win
  on next restart because they are loaded later.
- **Refinery never reassigns to the architect.** The
  `verify-architect` step never fired. Most likely the refinery is
  still running `mol-refinery-pr-patrol` or
  `mol-refinery-review-loop-patrol`. See the previous bullet.
- **Architect picks the bead up but never writes a verdict.** Check
  the architect's session logs. The most common failure is the
  branch not being fetchable — `git fetch origin` didn't pull the
  polecat's branch because the polecat didn't push. Look at the
  bead's `metadata.branch` and confirm `git ls-remote origin
  refs/heads/<branch>` returns a SHA. If not, treat it as a polecat
  regression.
- **Architect rejects beads endlessly.** Check
  `metadata.review_loops`. The cap lives in the **refinery's**
  `verify-architect` step (`>=2` forces forward), so if the counter
  is stuck at `0` you're probably looking at an architect that isn't
  reassigning to the refinery, or a refinery that isn't reading
  `architect_approved=false` correctly. Verify the architect's
  `mol-architect-review` reassigns to refinery on rejection (it
  should — see step 2 of the formula), and that the refinery's
  patrol is `mol-refinery-architect-patrol`.
- **Cap tripped but the bead still bounced to polecat.** Once the
  refinery sets `review_cap_reached=true` and forces
  `architect_approved=true`, the next architect pass should approve
  on a fresh look (it's now a clean review, not a loop). If you
  still see a bounce after the cap, something else unset
  `architect_approved` between patrols — most likely a manual `gc bd
  update` or a stale wisp picking the bead up. Check `gc bd show
  $BEAD_ID` for the most recent value of `architect_approved` and
  `review_cap_reached`.
- **`watch` is not installed (macOS default).** Either `brew install
  watch`, or just re-run the `gc bd show $BEAD_ID` command by hand
  every few seconds.

## What's next

Continue to [Bead gate checks](../hardening/06-bead-gate-checks.md). The bead gate
closes the upstream hole this page leaves open: the architect runs
*after* the polecat has done work, so a malformed bead still wastes
a polecat pass before getting caught. The bead gate introduces a pre-
implementation `bead-reviewer` that checks each bead is well-formed
before any polecat is allowed to claim it.

« [previous: the branch-protection appendix](./03-branch-protection.md) | [next: the bead gate option](../hardening/06-bead-gate-checks.md) »
