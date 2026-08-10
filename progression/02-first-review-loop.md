# First Review Loop

## Contents

- [Block W-4: Review Loops](#block-w-4-review-loops)
- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context](#context)
- [Setup](#setup)
  - [Bootstrap Factory1 with Script](#bootstrap-factory1-with-script)
  - [Build Factory1 by Hand](#build-factory1-by-hand)
    - [1. Install the review-loop-rig pack into factory1](#1-install-the-review-loop-rig-pack-into-factory1)
- [Try It](#try-it)
  - [1. Locate one bead from the first epic](#1-locate-one-bead-from-the-first-epic)
  - [2. Sling the bead to the polecat (PR mode)](#2-sling-the-bead-to-the-polecat-pr-mode)
  - [3. Watch the polecat work](#3-watch-the-polecat-work)
  - [4. Watch the refinery send the bead back with feedback](#4-watch-the-refinery-send-the-bead-back-with-feedback)
  - [5. Watch the polecat pick the bead back up and address the feedback](#5-watch-the-polecat-pick-the-bead-back-up-and-address-the-feedback)
  - [6. Watch the refinery approve and publish a PR](#6-watch-the-refinery-approve-and-publish-a-pr)
  - [7. Manually merge the PR](#7-manually-merge-the-pr)
  - [8. Repeat for `e.md`](#8-repeat-for-emd)
  - [9. Reflect](#9-reflect)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

By the end of this exercise you will have installed the `review-loop-rig` pack and demonstrated two letters reaching `main` after exactly one round of refinery feedback per bead.

## Prereqs

- Page [01](./01-basic-flow.md) complete: `pr-gate-city` and
  `pr-gate-rig` are imported, `a.md`/`b.md`/`c.md` are merged via PR,
  the refinery is running on `mol-refinery-pr-patrol`.
- You're inside the rig directory. If you opened a fresh shell,
  re-export `$FACTORY_PATH`, `$ASCII_ART_PATH`, `$TUTORIAL_PATH`, and
  `$ARTIFACTS_PATH` per [00.3](./00.3-setup-foundation.md), then
  `cd "$ASCII_ART_PATH"`.
- `gh` is authenticated and can create PRs against the rig's GitHub
  repo. Verify with `gh auth status` and `gh repo view`.
- `jq` is installed (the new formula uses it).

## Context

Branching/Merging strategy is unchanged from page 01. What changes
here is the refinery's behavior between rebase and PR publish: it now
does **one** required round of feedback before the bead is allowed to
reach the approval gate.

Agent workflow with the loop in place:

1. The **coder** (polecat) claims a bead and implements as before. When
   the polecat believes the work is done, it pushes its branch and
   reassigns the bead to the refinery.
1. The **reviewer** (refinery) rebases the branch and runs checks. On
   the *first* patrol of any bead, it identifies at least one required
   modification, writes that feedback onto the bead, sets
   `metadata.review_loops=1`, and bounces the bead back to the polecat
   pool with a `rejection_reason`. No PR yet.
1. A polecat picks the bead back up, reads `metadata.review_feedback`
   (and the standard `rejection_reason`), addresses the modification,
   and reassigns to the refinery.
1. On the *second* patrol, the refinery sees `review_loops>=1`, skips
   the loop, and proceeds through the inherited approval-review and
   merge-push steps. A clean bead becomes a PR.
1. The **merger** (human, for now) merges the PR exactly as on page 01.

The next three pages add deeper gates on top of this loop:
branch protection on the GitHub side, an ADR-aware reviewer, and a
bead-level review before any polecat is allowed to claim work.

## Setup

This lesson has two paths to the same end state. Pick one.

### Bootstrap Factory1 with Script

If this is your first run, complete the one-time setup in the [bootstrap README](../bootstrap/README.md) (`.env`, `deps.sh`) before invoking the script.

**Copy and paste**

```bash
cd path/to/sf-tutorial/bootstrap
./bootstrap.sh 02-first-review-loop
```

The script reproduces every step up through this lesson — `review-loop-rig` is added at rig scope, `pr-gate-rig` is removed from the rig's direct imports (still resolved transitively), and the city is restarted.

After it finishes, re-export the four env vars per [00.3](./00.3-setup-foundation.md), then jump to [Try It](#try-it).

### Build Factory1 by Hand

### 1. Install the review-loop-rig pack into factory1

The page 01 setup left the refinery as a single-shot approver: read the
diff, stamp `refinery_approved=true`, publish a PR. There is no
mechanism for the refinery to ask the polecat to revise its work — it
either approves or blocks. We want a softer gate on the way in: one
required round of feedback before any bead is allowed to land as a PR.

This ships as a single rig-scoped pack, **`review-loop-rig`**, that
extends what `pr-gate-rig` already gave us:

- A new formula `mol-refinery-review-loop-patrol` that extends
  `mol-refinery-pr-patrol` with one new step, `feedback-loop`. The step
  fires on the first patrol of each bead, writes targeted feedback onto
  the bead, bumps `metadata.review_loops` to 1, and bounces the bead
  back to the polecat pool. On the second patrol, the step is a no-op
  and the inherited `approval-review` and `merge-push` steps run as
  before.
- A `[[patches.agent]]` block that overrides the refinery's prompt
  template — pointing the rig refinery at
  `mol-refinery-review-loop-patrol` instead of `mol-refinery-pr-patrol`
  on next start.

The new pack declares two imports: `setup` (so the refinery prompt
patch resolves — patches resolve against the pack's own agents plus its
declared imports) and `pr-gate-rig` (so the new formula can `extends =
["mol-refinery-pr-patrol"]`). Once `review-loop-rig` is installed at the
rig, `pr-gate-rig` is removed from the rig's direct imports — the new
pack imports it transitively, so `mol-polecat-pr` and the inherited
patrol steps remain resolvable.

`pr-gate-city` (the mayor patch) stays in place. Its dispatch guidance
(`gc sling <rig>/polecat <bead> --on mol-polecat-pr`) is unchanged.

Inspect the pack before installing:

**Copy and paste**

```bash
ls "$ARTIFACTS_PATH/packs/review-loop-rig/"
cat "$ARTIFACTS_PATH/packs/review-loop-rig/pack.toml"
cat "$ARTIFACTS_PATH/packs/review-loop-rig/formulas/mol-refinery-review-loop-patrol.formula.toml"
```

You should see `pack.toml`, a `formulas/` directory with one
`.formula.toml`, and a `prompts/` directory with the refinery template.

Copy the pack into the city's pack directory:

**Copy and paste**

```bash
cp -r "$ARTIFACTS_PATH/packs/review-loop-rig" \
      "$FACTORY_PATH/.gc/system/packs/review-loop-rig"
```

Now register the new import at rig scope and remove the now-redundant
direct `pr-gate-rig` import. Run from the city directory:

**Copy and paste**

```bash
cd "$FACTORY_PATH"

# Add the new pack at rig scope.
gc import add --rig ascii-art .gc/system/packs/review-loop-rig

# Remove pr-gate-rig from the rig's direct imports.
# review-loop-rig imports it, so its formulas (including
# mol-polecat-pr) remain resolvable transitively.
gc import remove --rig ascii-art pr-gate-rig
```

Verify the rig now imports `review-loop-rig` and not `pr-gate-rig`:

**Copy and paste**

```bash
gc import list --rig ascii-art
```

**Expected output**

```text
review-loop-rig	.gc/system/packs/review-loop-rig		(path)
```

**Copy and paste**

```bash
gc import list
```

**Expected output**

```text
pr-gate-city	.gc/system/packs/pr-gate-city		(path)
```

Restart the city so the new patches and formulas take effect:

**Copy and paste**

```bash
gc restart
```

Confirm the new formula loaded and the refinery is pointed at it:

**Copy and paste**

```bash
gc formula list | grep -E "mol-refinery-review-loop-patrol|mol-polecat-pr"
```

**Expected output**

```text
mol-polecat-pr
mol-refinery-review-loop-patrol
```

## Try It

### 1. Locate one bead from the first epic

Three letters merged on page 01. List the remaining open `Implement
<letter>.md` tasks and grab the next one:

**Copy and paste**

```bash
cd "$ASCII_ART_PATH"
bd list --type=task --status=open --limit 0 | grep "Implement [d-f]\.md"
```

Pick `d.md` and capture its ID:

**Copy and paste**

```bash
export BEAD_ID=$(bd list --type=task --status=open --limit 0 | grep -E "Implement d\.md$" | awk '{print $2}')
bd show $BEAD_ID
```

You should see `metadata.target_file=ascii/d.md` and no `review_loops`
field yet — the refinery will write that during the first patrol.

### 2. Sling the bead to the polecat (PR mode)

Same dispatch recipe as page 01 — the loop is entirely on the refinery
side, so the polecat dispatch is unchanged:

**Copy and paste**

```bash
cd $FACTORY_PATH
gc sling ascii-art/review-loop-rig.polecat $BEAD_ID --on mol-polecat-pr
```

When this works, you should see the task sent to the agent along with
the formula:

**Expected output**

```text
⎿  Auto-convoy aa-0s7
    Attached wisp aa-3ii (formula "mol-polecat-pr") to aa-ne 1
    Slung aa-nel.1 (with formula "mol-polecat-pr") → ascii-art/review-loop-rig.polecat
```

The bead will look like this before being picked up:

**Expected output**

```text  
○ aa-7ln.11 · Implement d.md   [● P2 · OPEN]
Owner: Austin Born · Type: task
Created: 2026-05-08 · Updated: 2026-05-08

DESCRIPTION
  (none)

METADATA
  gc.routed_to: ascii-art/review-loop-rig.polecat
  molecule_id: aa-h77zz
  target_file: ascii/d.md

PARENT
  ↑ ○ aa-j6mbu: sling-aa-7ln.11 ● P2
```

### 3. Watch the polecat work

In another terminal, list the live agent sessions:

**Copy and paste**

```bash
gc session list
```

Watch the polecat pick up the bead and address the feedback:

**Copy and paste**

```bash
# Attach to the polecat session
gc session attach <polecat-session>

# WARNING: a `tmux` session will open, but if you give it a prompt this will interrupt
#its session. When you are done, detach from the session by pressing `Ctrl+b` and then `d`.
```

Back in the other terminal, the bead transitions `OPEN → IN_PROGRESS` once the polecat claims it.
Then, once the polecat's work is complete, the metadata should change to something like this:

**Expected output**

```text
○ aa-7ln.11 · Implement d.md   [● P2 · OPEN]
Owner: Austin Born · Assignee: ascii-art/review-loop-rig.refinery · Type: task
Created: 2026-05-08 · Started: 2026-05-08 · Updated: 2026-05-08

DESCRIPTION
  (none)

NOTES
Implemented: ascii/d.md — symmetric D (14 lines × 16 cols), d-style letter.            


METADATA
  branch: gc-review-loop-rig.furiosa-k-282324
  gc.routed_to: ascii-art/review-loop-rig.refinery
  merge_strategy: pr
  molecule_id: aa-h77zz
  target: main
  target_file: ascii/d.md
  work_dir: /Users/austin/software-factory-intensive/factory1/.gc/worktrees/ascii-art/polecats/review-loop-rig.furiosa

PARENT
  ↑ ○ aa-j6mbu: sling-aa-7ln.11 ● P2
```

### 4. Watch the refinery send the bead back with feedback

When the polecat finishes, it reassigns the bead to the refinery. The
refinery rebases the feature branch onto the latest `main`, runs the
rig's checks, and then — because `metadata.review_loops` is unset — runs
the `feedback-loop` step. The step writes a one-or-more-sentence
required modification onto the bead and bounces the bead back to the
polecat pool.

**Copy and paste**

```bash
gc session list

# Attach to the refinery session
gc session attach <refinery-session>

# Remember to use `Ctrl+b` and then `d` to detach from the session.
```

Once the refinery has finished its first pass, you should see the bead notes and metadata change:

**Expected output**

```text
○ aa-7ln.11 · Implement d.md   [● P2 · OPEN]
Owner: Austin Born · Type: task
Created: 2026-05-08 · Started: 2026-05-08 · Updated: 2026-05-08

DESCRIPTION
  (none)

NOTES
<additional notes from the refinery>                               


METADATA
  branch: gc-review-loop-rig.furiosa-k-282324
  gc.routed_to: ascii-art/review-loop-rig.polecat
  merge_strategy: pr
  molecule_id: aa-h77zz
  rejection_reason: <rejection reason from the refinery>
  review_loops: 1
  target: main
  target_file: ascii/d.md
  work_dir: /Users/austin/software-factory-intensive/factory1/.gc/worktrees/ascii-art/polecats/review-loop-rig.furiosa

PARENT
  ↑ ○ aa-j6mbu: sling-aa-7ln.11 ● P2
```

### 5. Watch the polecat pick the bead back up and address the feedback

Now using `gc session` again, you should be able to watch the polecat to see it pick up the bead and address the feedback. It will finally update the bead and reassign to the refinery.

### 6. Watch the refinery approve and publish a PR

Finally, back to the refinery session, you should be able to watch the refinery to see it clear the second patrol and publish a PR. It should add a few lines to the metadata and open a PR:

**Expected output**

```text
...

METADATA
  refinery_approval_at: 2026-05-08T23:29:14Z
  refinery_approved: true
...
```

If the refinery had blocked the bead at approval-review instead, the
behavior would match the pr-gate block path from page 01:
`refinery_approved: "false"`, `blocked_reason: "<reason>"` populated. The loop runs once
and is done; an approval block on the second patrol is a separate concern.

### 7. Manually merge the PR

**Copy and paste**

```bash
cd $ASCII_ART_PATH
export PR=$(BD_JSON_ENVELOPE=1 gc bd show $BEAD_ID --json | jq -r '.data[0].metadata.pr_number')
gh pr view $PR
gh pr view $PR --web   # open in browser
```

Click **Merge pull request** in GitHub (or `gh pr merge "$PR" --merge`).

### 8. Repeat for `e.md`

Same pattern, one more time — sling, watch the loop fire, watch the
polecat address the feedback, watch the refinery clear the second
patrol, manually merge:

**Copy and paste**

```bash
cd $ASCII_ART_PATH
export BEAD_ID=$(bd list --type=task --status=open --limit 0 | grep -E "Implement e\.md$" | awk '{print $2}')

cd $FACTORY_PATH
gc sling ascii-art/review-loop-rig.polecat $BEAD_ID --on mol-polecat-pr
```

### 9. Reflect

That worked. Another letter reached `main` — but it made two
trips through the polecat: once to write the file, once to address one
required modification from the refinery. The refinery is no longer
purely a gate; it's a (very lightweight) reviewer that always asks for
at least one revision.

What's still missing:

- **The loop is hard-coded to one round.** The refinery cannot ask for
  a second round of revisions even if the polecat's first revision
  doesn't fix the issue. **Hardening 4 — Strengthen review system**
  generalizes the loop into a configurable maximum.
- **The required modification is whatever the refinery thinks of in
  the moment.** There's no domain knowledge driving the ask — no ADR,
  no design intent, no separate testing or documentation lens.
  **Page 04 — ADR-aware reviewer** introduces a dedicated reviewer
  agent that reads the controlling ADR and gives the refinery a more
  substantive read.
- **The PR is still mergeable by anyone with write access.** No
  required reviewers, no required CI on the GitHub side. **Page 03 —
  Branch protection** wires that up.
- **Bead malformation still gets caught downstream.** A bead with a
  wrong title or a bad `target_file` will still get claimed by a
  polecat and only get bounced after the polecat has already done work.
  **Page 05 — Bead review gate** closes that hole.

## Verification

**Copy and paste**

```bash
# 1. Two new commits on origin/main from the polecat → loop → polecat → refinery → PR cycle.
cd $ASCII_ART_PATH
git fetch origin && git pull
git log --oneline origin/main
```

**Expected output**

```text
2 new merge commits whose messages reference Implement d.md / e.md
(in addition to the 3 from page 01).
```

**Copy and paste**

```bash
# 2. Two pull requests merged on the rig's GitHub repo since page 01.
gh pr list --state=merged --limit 10
```

**Expected output**

```text
at least 5 merged PRs total (a, b, c from page 01 plus d, e from this page).
```

**Copy and paste**

```bash
# 3. Worktrees cleaned up — only the main worktree remains in $ASCII_ART_PATH
git worktree list
```

**Expected output**

```text
a single line for the rig's main checkout.
```

**Copy and paste**

```bash
# 4. The two new files exist on disk.
ls ascii/d.md ascii/e.md
```

**Expected output**

```text
both paths print without error.
```

## Troubleshooting

- **`gc formula list` doesn't show `mol-refinery-review-loop-patrol`.**
  The `review-loop-rig` pack didn't load. Run `gc import list --rig
  ascii-art` and confirm you see `review-loop-rig`. If it's missing,
  re-run `gc import add --rig ascii-art
  .gc/system/packs/review-loop-rig` and restart.
- **`gc import remove --rig ascii-art pr-gate-rig` errors with
  "still in use" or similar.** Some installations may complain because
  `review-loop-rig` imports `pr-gate-rig`. The transitive dependency is
  fine; if `gc import remove` refuses, leave `pr-gate-rig` in the rig's
  imports — `review-loop-rig`'s prompt patch will still win on next
  restart because it's loaded later, but verify with the `gc agent
  show` check above.
- **Refinery patrols but `review_loops` never gets written.** The
  `feedback-loop` step never fired. Check the refinery's session logs;
  most likely the patch didn't take effect and the refinery is still
  running `mol-refinery-pr-patrol`. See the previous troubleshooting
  item.
- **`review_loops=1` but the polecat never re-claims the bead.** The
  bead bounce is fine but the reconciler isn't dispatching. Check that
  `metadata.gc.routed_to` is set to `ascii-art/polecat` (not blank, not
  `ascii-art/review-loop-rig.polecat` — the `routed_to` value is the bare
  agent address). If `assignee` is also set to a stale value, clear it
  with `gc bd update $BEAD_ID --assignee=""`.
- **Refinery loops twice on the same bead.** The step's check on
  `metadata.review_loops` failed to gate the second pass. Confirm the
  bead has `review_loops="1"` (string `"1"`, not the integer `1` —
  beads metadata is stringly-typed). The `[ "$LOOPS" -ge 1 ]` test in
  the step body handles either, but if the field was unset between
  patrols, the step will fire again.
- **Refinery sets `refinery_approved=false` after the loop.** That's
  the inherited approval gate doing its job on the second patrol. Read
  `metadata.blocked_reason` — most likely the polecat's revision
  introduced a new problem (off-scope edit, empty file). Treat as a
  page 01 approval block: re-sling once, escalate if it blocks twice.
- **`gh pr create` fails with auth or remote errors.** Same as page
  01 — `git remote -v` should show `origin` pointing at the GitHub repo
  from page 00.2. If it doesn't, the refinery's `gh pr create` will
  open the PR on the wrong repository (or fail).
- **`watch` is not installed (macOS default).** Either `brew install
  watch`, or just re-run the `gc bd show $BEAD_ID --json | jq ...`
  pipeline by hand every few seconds.

## What's next

Continue to [Branch protection](./03-branch-protection.md). Page 03
closes the GitHub-side hole this page leaves open: a PR cleared by the
refinery is still mergeable by anyone with write access, with no
required CI and no human review. Branch protection wires those gates
in.

« [previous: 01 Basic flow](./01-basic-flow.md) | [next: 03 Branch protection](./03-branch-protection.md) »
