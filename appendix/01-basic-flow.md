# Basic Flow

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context](#context)
- [Setup](#setup)
  - [Bootstrap Factory1 with Script](#bootstrap-factory1-with-script)
  - [Build Factory1 by Hand](#build-factory1-by-hand)
    - [1. Install the pr-gate packs into factory1](#1-install-the-pr-gate-packs-into-factory1)
- [Try It](#try-it)
  - [1. Locate one bead from the first epic](#1-locate-one-bead-from-the-first-epic)
  - [2. Sling the bead to the polecat (PR mode)](#2-sling-the-bead-to-the-polecat-pr-mode)
  - [3. Watch the polecat work](#3-watch-the-polecat-work)
  - [4. Watch the refinery approve and publish a PR](#4-watch-the-refinery-approve-and-publish-a-pr)
  - [5. Manually merge the PR](#5-manually-merge-the-pr)
  - [6. Repeat for `b.md` and `c.md`](#6-repeat-for-bmd-and-cmd)
  - [7. Reflect](#7-reflect)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

By the end of this exercise you will have three letters from the `letters-a-m` epic landed on `main` through real GitHub pull requests, each one approved by the refinery before publication.

## Prereqs

- Pages [W3 Run Your Factory](../progression/W3-run-your-factory.md), [W3 Run Your Factory](../progression/W3-run-your-factory.md),
  and [W3 Run Your Factory](../progression/W3-run-your-factory.md) complete: city stood up with setup
  pack imported, rig registered with locked docs in place, 138 beads seeded, and
  `main` pushed to GitHub.
- `$SFI_PATH` set in your shell. [W2](../progression/W2-cloud-box-and-preflight.md) and [W3](../progression/W3-run-your-factory.md) both append it to a shell rc, so it survives a new terminal. Every other path on this page is written out from it.
- You're inside the rig directory: `cd "$SFI_PATH/ascii-art"`.
- `gh` is authenticated and can create PRs against the rig's GitHub repo.
  Verify with `gh auth status` and `gh repo view`.
- `jq` is installed (the new formulas use it).

## Context

Install the `pr-gate-city` and `pr-gate-rig` packs into your
`factory1` city, restart so the packs' mayor and refinery overrides
take effect, then sling one bead from the `letters-a-m` epic at the
polecat using the new `mol-polecat-pr` formula. Watch the polecat
work, watch the refinery rebase + run checks + clear the bead at its
approval gate, and see a real GitHub PR open. Manually merge the PR.
Repeat for two more letters. Reflect on what just happened: every
change reaches `main` through a PR, and only PRs the refinery has
approved make it that far.

The next four pages add deeper gates on top of this baseline:
ADR-aware reviewers, branch protection on the GitHub side, and
bead-level review before any polecat is allowed to claim work.

Branching/Merging strategy:

1. Epics branch off and target `main` (or their parent epic's branch, where applicable). The branches are named like this: `epic/<bead-id>--<slug>`, for example `epic/aa-x1z--add-pinch-gesture`.
1. Tasks branch off and target their parent's branch (normally an epic). They're named like this: `task/<bead-id>--<slug>`, for example `task/aa-x1z.1--change-notification-colors`.
1. Only humans can approve merge into `main`.
1. Coder agents work on their branch in a worktree named after the bead they're working on (e.g. `<bead-id>--<slug>`, for example `aa-x1z.1--change-notification-colors`, `aa-x1z--add-pinch-gesture`).

Agent workflow:

1. A **coder** agent claims a bead and implements. The coder checks their own work against the bead's requirements and acceptance criteria. When the coder believes the work is done, they open a GitHub pull request, and then hand off the bead to someone else for review.
1. A **reviewer** agent reviews the PR and corresponding bead. If the work fulfills the requirements of the bead, the reviewer notes their approval in both the bead and the pull request on GitHub. (The agent does not have to repeat themself, one can reference the other to 'See additional details'. But both should indicate approval or rejection.) If the work does not fulfill the requirements, the bead should be routed back to the coder with specific feedback about why the bead is not ready to be closed, and what work needs to be done to complete it.
1. A **merger** agent reviews beads that have been approved, merges corresponding pull requests, and then closes the corresponding bead.

## Setup

This lesson has two paths to the same end state. Pick one.

### Bootstrap Factory1 with Script

If this is your first run, complete the one-time setup in the [bootstrap README](../bootstrap/README.md) (`.env`, `deps.sh`) before invoking the script.

**Copy and paste**

```bash
cd path/to/sf-tutorial/bootstrap
./bootstrap.sh 01-basic-flow
```

The script reproduces every step up through this lesson — `pr-gate-city` and `pr-gate-rig` are imported, the city's `mayor` agent directory is removed so the new pack's mayor takes the role, and the city is restarted.

After it finishes, jump to [Try It](#try-it).

### Build Factory1 by Hand

### 1. Install the pr-gate packs into factory1

The OOTB setup pack ships polecat + refinery in **direct-merge** mode:
the polecat does the work, the refinery rebases and fast-forwards it
straight onto `main`. There is no PR stage and no human or AI gate
between the polecat's commit and the protected branch.

We want a PR-based gate from page one — and a twist: only beads the
refinery has actually approved should make it to the PR stage. Code
that doesn't pass approval should be bounced back to the polecat pool,
not silently published as a PR for a human to clean up.

This ships as a **pair of packs** — `pr-gate-city` and `pr-gate-rig`.
Two packs because gascity's pack-v2 patches can only target agents in
the same composition pass: mayor is city-scoped, refinery is
rig-scoped, so each scope needs its own pack.

**`pr-gate-city`** delivers:

- The city's `mayor` agent, teaching the mayor the new dispatch
  recipe (`--on mol-polecat-pr`) and how to triage beads blocked at
  the gate. It replaces the mayor `gc init` wrote rather than amending
  it, because a pack patch can only reach agents the pack itself
  declares or imports, and the stock mayor is neither.

**`pr-gate-rig`** delivers:

- `mol-polecat-pr` — a polecat formula that stamps `merge_strategy=pr`
  on the work bead, so the refinery publishes a PR instead of merging
  directly.
- `mol-refinery-pr-patrol` — a refinery patrol formula that adds an
  `approval-review` step between checks and merge-push. Beads that pass
  the gate become PRs; beads that fail go back to the polecat pool with
  `metadata.refinery_approved=false` and a `blocked_reason`.
- A `[[patches.agent]]` block that overrides the refinery's
  prompt template — pointing the rig refinery at
  `mol-refinery-pr-patrol` instead of `mol-refinery-patrol` on next
  start.

Each pack also declares `[imports.setup]`.
A patch resolves against the pack's own agents *plus* its declared
imports — so for the `mayor`/`refinery` patches to find their target,
the pack defining the patch has to import setup directly. At the
same time, to ensure unambiguous resolution, the setup pack
is also removed from the city's direct imports.

Inspect the packs before installing:

**Copy and paste**

```bash
ls "$SFI_PATH/sf-tutorial/artifacts/packs/pr-gate-city/"
ls "$SFI_PATH/sf-tutorial/artifacts/packs/pr-gate-rig/"
cat "$SFI_PATH/sf-tutorial/artifacts/packs/pr-gate-rig/formulas/mol-polecat-pr.formula.toml"
cat "$SFI_PATH/sf-tutorial/artifacts/packs/pr-gate-rig/formulas/mol-refinery-pr-patrol.formula.toml"
```

`pr-gate-city/` contains `pack.toml` and an `agents/mayor/` directory
holding the mayor template. `pr-gate-rig/` contains `pack.toml`, a `prompts/`
directory with the refinery template, and a `formulas/` directory
with two `.formula.toml` files.

Copy both packs into the city's `packs/` directory:

**Copy and paste**

```bash
mkdir -p "$SFI_PATH/factory1/packs"

# Delete first: cp -r copies the source *into* the destination when the destination already exists, so a second run would nest the pack.
rm -rf "$SFI_PATH/factory1/packs/pr-gate-city" "$SFI_PATH/factory1/packs/pr-gate-rig"

cp -r "$SFI_PATH/sf-tutorial/artifacts/packs/pr-gate-city" \
      "$SFI_PATH/factory1/packs/pr-gate-city"

cp -r "$SFI_PATH/sf-tutorial/artifacts/packs/pr-gate-rig" \
      "$SFI_PATH/factory1/packs/pr-gate-rig"
```

Confirm both packs landed flat, with a single `pack.toml` at the top level of each:

**Copy and paste**

```bash
find "$SFI_PATH/factory1/packs/pr-gate-city" "$SFI_PATH/factory1/packs/pr-gate-rig" -name pack.toml
```

**Expected output**

```text
$SFI_PATH/factory1/packs/pr-gate-city/pack.toml
$SFI_PATH/factory1/packs/pr-gate-rig/pack.toml
```

Now register both packs as imports. `gc import add` is the supported
way to do this — it validates the source, derives the binding name,
writes the right TOML block, and updates `packs.lock`. Run from the
city directory:

**Copy and paste**

```bash
cd "$SFI_PATH/factory1"

# City scope — pr-gate-city supplies the city-scoped mayor agent.
gc import add packs/pr-gate-city

# Rig scope — pr-gate-rig patches the rig-scoped refinery agent and
# loads the polecat/refinery formulas. Bound to the ascii-art rig.
gc import add --rig ascii-art packs/pr-gate-rig

# Remove setup pack since pr-gate-rig transitively imports it now.
gc import remove --rig ascii-art setup
```

Verify both imports landed:

**Copy and paste**

```bash
gc import list
gc import list --rig ascii-art
```

**Expected output**

```text
city-scoped: pr-gate-city
rig-scoped:  pr-gate-rig
```

Now hand the mayor's role to the pack. Remove the city's own `mayor` agent, then point the always-on session at the pack's mayor.

**Copy and paste**

```bash
rm -rf "$SFI_PATH/factory1/agents/mayor"

sed '/^\[\[named_session\]\]/,/^[[:space:]]*mode = /d' "$SFI_PATH/factory1/pack.toml" > "$SFI_PATH/factory1/pack.toml.tmp"
cat >> "$SFI_PATH/factory1/pack.toml.tmp" <<'EOF'
[[named_session]]
name = "mayor"
template = "pr-gate-city.mayor"
mode = "always"
EOF
mv "$SFI_PATH/factory1/pack.toml.tmp" "$SFI_PATH/factory1/pack.toml"
```

Keeping `name = "mayor"` preserves the session's alias, so `gc session attach mayor` still works. The template names the binding, because a bare `mayor` stops resolving once the city's own agent directory is gone.

> **Why not `sed -i`?** GNU `sed` on Linux and BSD `sed` on macOS disagree about the argument `-i` takes, so no single `sed -i` spelling runs on both. Writing to a temp file and moving it back behaves identically everywhere. The same idiom appears wherever this tutorial edits a file in place.

Now restart the city so the new patches and formulas take effect:

**Copy and paste**

```bash
gc restart
```

Confirm the new formulas loaded:

**Copy and paste**

```bash
gc formula list | grep -E "mol-polecat-pr|mol-refinery-pr-patrol"
```

**Expected output**

```text
mol-polecat-pr
mol-refinery-pr-patrol
```

## Try It

### 1. Locate one bead from the first epic

List the open `Implement <letter>.md` tasks and grab the first three:

**Copy and paste**

```bash
cd "$SFI_PATH/ascii-art"
bd list --type=task --status=open --limit 0 | grep "Implement [a-c]\.md"
```

If you see `Error: failed to open database`, remember you can run `bd config set dolt.auto-start true`
in the rig scope as well.

Pick one task — say `Implement a.md` — and capture its ID. IDs look like
`asciiart-14` (the prefix matches what you initialized with in page 00). Look
at the bead's metadata so you know what the agents will see:

**Copy and paste**

```bash
export BEAD_ID=$(bd list --type=task --status=open --limit 0 | grep -E "Implement a\.md$" | awk '{print $2}')
bd show $BEAD_ID
```

You should see fields including `metadata.target_file=ascii/a.md`. The polecat
reads that metadata to know what file it's writing.

### 2. Sling the bead to the polecat (PR mode)

Hand the bead to the `ascii-art/pr-gate-rig.polecat` agent using the new
pr-gate formula:

**Copy and paste**

```bash
cd $SFI_PATH/factory1
gc sling ascii-art/pr-gate-rig.polecat $BEAD_ID --on mol-polecat-pr
```

When this works, you should see the task sent to the agent along with
the formula for how to process it:

**Expected output**

```text
⎿  Auto-convoy aa-0s7
    Attached wisp aa-3ii (formula "mol-polecat-pr") to aa-ne 1
    Slung aa-nel.1 (with formula "mol-polecat-pr") → ascii-art/pr-gate-rig.polecat
```

What this does: the polecat creates a feature branch in a fresh git
worktree, stamps `metadata.merge_strategy=pr` on the bead (so the
refinery knows to publish a PR), implements the work the bead
describes, runs a self-review pass, and hands the bead off to the
refinery for landing.

If you slung with `--on mol-polecat-work` (the OOTB formula) instead,
the merge-strategy stamp would be missing and the refinery would
fast-forward the branch into `main` with no PR and no approval gate.
The pr-gate contract depends on `mol-polecat-pr`.

### 3. Watch the polecat work

In another terminal, list the live agent sessions to confirm `polecat` is running:

**Copy and paste**

```bash
gc session list
```

To view the agent's session in real time, you can attach to it:

**Copy and paste**

```bash
gc session attach <polecat-session>
```

WARNING: a `tmux` session will open, but if you give it a prompt this will interrupt
its session. When you are done, detach from the session by pressing `Ctrl+b` and then `d`.

If you haven't noticed progress after a minute or two, you can also nudge the agent to prompt
it without attaching to the session. This is the same as attaching to the session,
giving a prompt, then detaching:

**Copy and paste**

```bash
gc session nudge <polecat-session> "Check for any assigned work"
```

The bead transitions `open → in_progress` once the polecat claims it. Inspect
it again and you'll see new metadata stamped on:

**Copy and paste**

```bash
gc bd show $BEAD_ID
```

**Expected output**

```text
◐ aa-985.2 · Implement a.md   [● P2 · IN_PROGRESS]
Owner: Austin Born · Assignee: pr-gate-rig__polecat-fa-r3am · Type: task
Created: 2026-05-11 · Started: 2026-05-11 · Updated: 2026-05-11

DESCRIPTION
  (none)

METADATA
  branch: polecat/aa-985.2
  gc.routed_to: ascii-art/pr-gate-rig.polecat
  molecule_id: aa-vlh
  target_file: ascii/a.md
  work_dir: $SFI_PATH/factory1/.gc/worktrees/ascii-art/polecats/pr-gate-rig.furiosa/worktrees/aa-985.2

PARENT
  ↑ ○ aa-52p: sling-aa-985.2 ● P2
```

### 4. Watch the refinery approve and publish a PR

When the polecat finishes, it sets `metadata.merge_strategy=pr` and reassigns
 the bead to the refinery.
 
**Copy and paste**

```bash
gc bd show $BEAD_ID
```

**Expected output**

```text
○ aa-985.2 · Implement a.md   [● P2 · OPEN]
Owner: Austin Born · Type: task
Created: 2026-05-11 · Started: 2026-05-11 · Updated: 2026-05-11

DESCRIPTION
  (none)

NOTES
Implemented ASCII art for letter B: 7-line stacked-bumps B inside 7x7 canvas, rhyming couplet       
'round/sound'.                                                                                      


METADATA
  branch: polecat/aa-985.2
  gc.routed_to: ascii-art/refinery
  merge_strategy: pr
  molecule_id: aa-vlh
  target: main
  target_file: ascii/a.md
  work_dir: <your-home>/software-factory-intensive/factory1/.gc/worktrees/ascii-art/polecats/pr-gate-rig.furiosa/worktrees/aa-985.2

PARENT
  ↑ ○ aa-52p: sling-aa-985.2 ● P2
```

The refinery then picks up the bead and rebases the feature branch onto the latest `main`, runs the
rig's checks (none yet on the ascii-art rig — see Troubleshooting),
runs the **approval-review** step against the diff, and then — because
`metadata.merge_strategy=pr` — publishes a GitHub pull request.

You can watch the bead's metadata flip in a tight loop. The
interesting fields are `refinery_approved`, `pr_url`, and `pr_number`.

**Copy and paste**

```bash
# If you have watch installed:
watch -n 5 'gc bd show $BEAD_ID --json'

# If you don't have watch installed:
while true; do clear; gc bd show $BEAD_ID; sleep 5; done
```

For a clean letter (a, b, c) you should see `refinery_approved: "true"`
appear, followed shortly by `pr_url` set to a real
`https://github.com/...` link and `pr_number` set to a numeric value.
The refinery also closes the bead at PR-publish time.

If the refinery had blocked the bead instead, you'd see
`refinery_approved: "false"` and `blocked_reason` populated, and the
bead's status would flip back to `open` with no `pr_url`. (The block
path is exercised intentionally later in the progression once the rig
has misbehaving polecat output to chew on; for `a.md`/`b.md`/`c.md`
the gate clears.)

### 5. Manually merge the PR

Open the PR and look at the diff:

**Copy and paste**

```bash
cd $SFI_PATH/ascii-art
export PR=$(BD_JSON_ENVELOPE=1 gc bd show $BEAD_ID --json | jq -r '.data[0].metadata.pr_number')
gh pr view $PR
gh pr view $PR --web   # open in browser
```

Click **Merge pull request** in GitHub (or `gh pr merge "$PR" --merge`).

### 6. Repeat for `b.md` and `c.md`

Same pattern, two more times — sling with `mol-polecat-pr`, watch the
gate clear, manually merge the PR:

**Copy and paste**

```bash
cd $SFI_PATH/ascii-art
export BEAD_ID=$(bd list --type=task --status=open --limit 0 | grep -E "Implement b\.md$" | awk '{print $2}')

cd $SFI_PATH/factory1
gc sling ascii-art/pr-gate-rig.polecat $BEAD_ID --on mol-polecat-pr

cd $SFI_PATH/ascii-art
export BEAD_ID=$(bd list --type=task --status=open --limit 0 | grep -E "Implement c\.md$" | awk '{print $2}')

cd $SFI_PATH/factory1
gc sling ascii-art/pr-gate-rig.polecat $BEAD_ID --on mol-polecat-pr
```

Three letters from `letters-a-m` is enough. Resist the urge to chew
through the whole epic — later pages dispatch in larger batches and
you want clean state to compare against.

### 7. Reflect

That worked. Three letters reached `main` — but every commit went
through a real GitHub pull request, and every PR was approved by the
refinery before it was published. The refinery refused to be a passive
fast-forward machine; it read the diff, checked the file looked like a
real letter, and stamped `refinery_approved=true` before letting the
PR open. A bead that had landed empty or off-scope would have come
back to the polecat pool with a `blocked_reason` instead of becoming a
PR.

What's still missing:

- **No required reviewers on the GitHub side.** The PR can be merged by
  anyone with write access, with no required CI or human review. **Page
  03 — Branch protection** wires that up.
- **The refinery's approval is a single, generic gate.** It doesn't
  know the rig's ADR, doesn't know the design intent, doesn't have a
  separate testing or design lens. **The base factory's architect — ADR-aware reviewer**
  introduces a dedicated reviewer agent that reads the controlling ADR
  and gives the refinery a more substantive read.
- **There's no upstream check on the bead itself.** A malformed bead
  (wrong title, missing metadata, or pointing at a file the ADR
  forbids) will still get claimed by a polecat and only get caught
  downstream by the refinery's gate. **Page 05 — Bead review gate**
  closes that hole.
- **The pr-gate formula `mol-polecat-pr` is intentionally simple.**
  The richer variant in **Page 02 — PR formula and pack**
  (`mol-polecat-pr-work`) layers a bead-review precondition on top of
  the same merge-strategy stamp; that page is the deeper dive into how
  custom formulas extend OOTB ones.

## Verification

Three new commits on `origin/main` from the polecat/refinery → PR cycle:

**Copy and paste**

```bash
cd $SFI_PATH/ascii-art
git fetch origin && git pull
git log --oneline origin/main -3
```

**Expected output**

```text
3 commits whose messages reference Implement a.md / b.md / c.md
(subject + merge-commit messages set by the polecat and gh).
```

Three pull requests exist on the rig's GitHub repo:

**Copy and paste**

```bash
cd $SFI_PATH/ascii-art
gh pr list --state=merged --limit 5
```

**Expected output**

```text
at least 3 merged PRs corresponding to a.md, b.md, c.md.
```

Worktrees cleaned up — only the main worktree remains:

**Copy and paste**

```bash
git worktree list
```

**Expected output**

```text
a single line for the rig's main checkout.
```

The three files exist on disk:

**Copy and paste**

```bash
ls ascii/a.md ascii/b.md ascii/c.md
```

**Expected output**

```text
all three paths print without error.
```

## Troubleshooting

- **`gc formula list` doesn't show `mol-polecat-pr` or
  `mol-refinery-pr-patrol`.** The pr-gate-rig pack didn't load. Run
  `gc import list` and confirm you see `rig:ascii-art:pr-gate-rig`. If
  it's missing, re-run the `gc import add --rig ascii-art
  packs/pr-gate-rig` command from step 1 and restart.
- **`gc restart` errors with `agent "mayor" not found in pack`** (or
  the equivalent for `refinery`). You imported one of the pr-gate
  packs at the wrong scope. `pr-gate-city` supplies the city-scoped
  mayor and must be imported at city scope (no `--rig` flag);
  `pr-gate-rig` patches the rig-scoped refinery and must be imported
  with `--rig <rig-name>`. Run `gc import remove pr-gate-city` (or
  `pr-gate-rig`), then re-add at the correct scope.
- **Polecat doesn't claim the bead.** Check `gc agents` shows `polecat`
  is running. Then `bd show <bead-id>` — if `assignee` is blank a few
  seconds after the sling, the formula didn't dispatch. Re-run
  `gc sling` and watch for an error message.
- **Refinery rebases but no `pr_url` ever appears, and
  `refinery_approved` stays empty.** The approval-review step probably
  errored out. Look at the refinery's session logs for the diff it
  was reading; if the diff was empty, the polecat didn't actually
  write the file. Treat as a polecat regression.
- **Refinery sets `refinery_approved=false` for `a.md`.** Read
  `metadata.blocked_reason` — the refinery is telling you which check
  failed. Most often this is the polecat writing an empty file or
  putting it at the wrong path (`a.md` instead of `ascii/a.md`).
  Re-sling once; if it blocks twice in a row, check the polecat
  prompt for drift.
- **Refinery refuses to merge because CI fails.** The refinery runs
  typecheck/lint/test on the rebased branch before approval-review.
  The ascii-art rig has no test suite yet, so the refinery should
  take its "no checks configured" path and proceed cleanly. If it
  fails instead, check the refinery's session logs for which check
  it tried to run.
- **Pushed to the wrong remote.** `git remote -v` from the rig should
  show `origin` pointing at the GitHub repo you created when you set
  the rig up. If it points elsewhere, the refinery's `gh pr create` will
  fail or open the PR on the wrong repository.
- **Bead closes but the file is empty or missing.** Look at the
  polecat's session log. The log will show what the agent actually wrote and where.

  **Copy and paste**

  ```bash
  gc session logs <session-id>   # NOTE: command name varies; try `gc sessions logs`
  ```
- **`watch` is not installed (macOS default).** Either `brew install
  watch`, or just re-run the `bd show <bead-id> --json | jq ...`
  pipeline by hand every few seconds.

## What's next

Continue to [First review loop](./02-first-review-loop.md). Page 02
adds a single required round of refinery feedback before any bead is
allowed to land as a PR — installing a new `review-loop-rig` pack that
extends `mol-refinery-pr-patrol` with a `feedback-loop` step and
patches the refinery to use it, so every bead now makes two trips
through the polecat before reaching `main`.

« [previous: W3 Run Your Factory](../progression/W3-run-your-factory.md) | [next: the review-loop appendix](./02-first-review-loop.md) »
