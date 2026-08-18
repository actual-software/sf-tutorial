# Bead Gate Checks

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context](#context)
- [Setup](#setup)
  - [Bootstrap Factory1 with Script](#bootstrap-factory1-with-script)
  - [Build Factory1 by Hand](#build-factory1-by-hand)
    - [1. Install the bead-gate-rig pack into factory1](#1-install-the-bead-gate-rig-pack-into-factory1)
- [Try It](#try-it)
  - [1. Locate one bead from the first epic](#1-locate-one-bead-from-the-first-epic)
  - [2. Sling the bead at the project-manager (new entry point)](#2-sling-the-bead-at-the-project-manager-new-entry-point)
  - [3. Watch the project-manager run and the polecat pick up](#3-watch-the-project-manager-run-and-the-polecat-pick-up)
  - [4. Demonstrate the FAIL path](#4-demonstrate-the-fail-path)
  - [5. Unblock the bead by hand and re-sling](#5-unblock-the-bead-by-hand-and-re-sling)
  - [6. Demonstrate the test-generation gate](#6-demonstrate-the-test-generation-gate)
  - [7. Reflect](#7-reflect)
- [Refining a bead so the gate passes it](#refining-a-bead-so-the-gate-passes-it)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

By the end of this exercise you will have installed a `bead-gate-rig` pack that puts a `project-manager` agent at the front of the factory, slung a clean bead through it to the polecat pool, watched it block a deliberately malformed bead with feedback, and watched its test-generation check block a second bead that is well-formed but names no outcome a test could assert.

## Prereqs

- [W3](../progression/W3-run-your-factory.md) complete: the base factory installed on a rig, with the polecat, refinery and architect running.
- You are inside the rig directory, with `$FACTORY_PATH`, `$ASCII_ART_PATH`, `$TUTORIAL_PATH` and `$ARTIFACTS_PATH` exported, then `cd "$ASCII_ART_PATH"`.
- `gh` is authenticated and can create PRs against the rig's GitHub
  repo. Verify with `gh auth status` and `gh repo view`.
- `jq` is installed (the new formula uses it).

**This option needs no other option.** Its pack already imports the base factory's top node, so the architect and the refinery flow stay resolvable with nothing else installed.

## Context

Branching/Merging strategy is unchanged from the base factory's architect. What changes
here is **the entry point** to the factory. Before the bead gate, the
operator slung beads directly at the polecat. After the bead gate, every
bead is slung at a **project-manager** agent first, which runs a
small conformity checklist on the bead's title, description, and
metadata; routes well-formed beads to the polecat pool; and blocks
malformed beads for the operator to fix.

Agent workflow with the project-manager in place:

1. The **operator** (or the mayor, in larger flows) slings each new
   bead at the project-manager: `gc sling <rig>/bead-gate-rig.project-manager <bead> --on mol-bead-review`.
   The project-manager — not the polecat — is now the front door.
1. The **project-manager** (new) reads the bead's title,
   description, type, and metadata and walks a small checklist: title
   is meaningful, description names a deliverable, `target_file` is
   set on tasks and consistent with the title, parent epic exists,
   etc. It writes a verdict back onto the bead.
   - **PASS**: the project-manager stamps `bead_review_passed=true`
     and sets `gc.routed_to=<rig>/polecat`. The polecat pool's
     reconciler picks the bead up next; the polecat poured against
     the bead runs `mol-polecat-pr` (taught in the base factory).
   - **FAIL**: the project-manager stamps `bead_review_passed=false`
     and `bead_review_feedback=<reason>`, sets the bead's status to
     `blocked`, mails the mayor, and exits. The polecat pool ignores
     blocked beads, so the bead cannot accidentally enter
     implementation while the operator works through the feedback.
1. The **operator** reviews any blocked beads, fixes the underlying
   problem on the bead (correct the title, fill in the description,
   set `target_file`, etc.), runs `bd update <bead> --status=open`,
   and re-slings the project-manager for a clean re-review. Page
   The Grill-Me section below walks through using a Grill-Me skill in
   your local agent to refine beads quickly so the project-manager
   passes them on the first pass.
1. The **polecat / refinery / architect** chain (the base factory) runs
   exactly as before once the bead is in the polecat pool.

The project-manager does **not** push code, modify the bead's text
on the operator's behalf, run on closed or already-passed beads, or
review the polecat's eventual diff. It is a read + verdict-write
agent at the very front of the pipeline.

## Setup

This lesson has two paths to the same end state. Pick one.

### Bootstrap Factory1 with Script

If this is your first run, complete the one-time setup in the [bootstrap README](../bootstrap/README.md) (`.env`, `deps.sh`) before invoking the script.

**Copy and paste**

```bash
cd path/to/sf-tutorial/bootstrap
./bootstrap.sh 05.1-bead-gate-checks
```

The script reproduces every step up through this lesson — `bead-gate-rig` is added at rig scope, `architect-rig` is removed from the rig's direct imports (still resolved transitively), and the city is restarted.

After it finishes, re-export the four env vars per [W3 Run Your Factory](../progression/W3-run-your-factory.md), then jump to [Try It](#try-it).

### Build Factory1 by Hand

### 1. Install the bead-gate-rig pack into factory1

The base factory's architect gives the rig a downstream architecture review —
the architect reads each polecat's diff before the refinery merges.
But there is no upstream check on the **bead** itself. A bead with a
wrong title, a missing `target_file`, or a description that says
"TODO" will still get claimed by a polecat and only get caught
downstream by the architect — after the polecat has already burned a
session writing the wrong thing or the wrong file.

This ships as a single rig-scoped pack, **`bead-gate-rig`**, that
sits on top of `architect-rig`:

- A new rig-scoped agent `project-manager` (`scope = "rig"`, pool
  `min=0, max=1`) so bead reviews are serial and the mail/note
  stream stays readable. Bead review is fast — no diff, no docs
  walk, no model heavy lifting — so a single slot is plenty.
- A new formula `mol-bead-review` poured by the project-manager on
  each assigned bead. Reads the bead's title, description, type,
  parent (if any), and metadata; walks a conformity checklist; and
  writes a PASS or FAIL verdict.

The new pack declares one import: `architect-rig` (so the architect
agent and `mol-refinery-architect-patrol` remain resolvable
transitively). It does **not** add any `[[patches.agent]]` blocks —
the project-manager is a brand-new agent, no existing prompts are
overridden, and the polecat formulas do not need to gate on
`bead_review_passed=true` because beads simply do not reach the
polecat pool unless the project-manager routes them there.

`pr-gate-city` (the mayor patch) stays in place at city scope. The
mayor's pr-gate guidance is still useful for the post-PM polecat
dispatch; the new entry point — `gc sling <rig>/project-manager <bead> --on mol-bead-review` — is taught in this lesson rather than
patched into the mayor's prompt.

Inspect the pack before installing.

**Copy and paste**

```bash
ls "$ARTIFACTS_PATH/packs/bead-gate-rig/"
cat "$ARTIFACTS_PATH/packs/bead-gate-rig/pack.toml"
cat "$ARTIFACTS_PATH/packs/bead-gate-rig/agents/project-manager/agent.toml"
cat "$ARTIFACTS_PATH/packs/bead-gate-rig/agents/project-manager/prompt.template.md"
cat "$ARTIFACTS_PATH/packs/bead-gate-rig/formulas/mol-bead-review.formula.toml"
```

You should see `pack.toml`, an `agents/project-manager/` directory
with `agent.toml` and `prompt.template.md`, and a `formulas/`
directory with one `.formula.toml`.

What to notice in the pack:

- **One project-manager per rig.** `agent.toml` declares
  `scope = "rig"` with a serial pool (`min=0, max=1`).
- **Two outcomes only.** PASS routes to the polecat pool; FAIL
  blocks the bead. There is no half-pass or auto-fix path — the
  project-manager surfaces problems to the human, it does not
  rewrite bead text on the operator's behalf.
- **Status flips matter.** A FAIL sets `status=blocked`, which the
  polecat pool ignores. A PASS leaves the bead `open` and sets
  `gc.routed_to=<rig>/polecat`. The status is the durable signal.

Copy the pack into the city's `packs/` directory.

**Copy and paste**

```bash
mkdir -p "$FACTORY_PATH/packs"

# Delete first: cp -r copies the source *into* the destination when the destination already exists, so a second run would nest the pack.
rm -rf "$FACTORY_PATH/packs/bead-gate-rig"

cp -r "$ARTIFACTS_PATH/packs/bead-gate-rig" \
      "$FACTORY_PATH/packs/bead-gate-rig"
```

Confirm the pack landed flat, with a single `pack.toml` at its top level:

**Copy and paste**

```bash
find "$FACTORY_PATH/packs/bead-gate-rig" -name pack.toml
```

**Expected output**

```text
$FACTORY_PATH/packs/bead-gate-rig/pack.toml
```

Now register the new import at rig scope and remove the now-redundant
direct `architect-rig` import. Run from the city directory.

**Copy and paste**

```bash
cd "$FACTORY_PATH"

# Add the new pack at rig scope.
gc import add --rig ascii-art "$ARTIFACTS_PATH/packs/bead-gate-rig"

# Nothing is removed. This option sits alongside the base factory,
# which keeps its orders and resolves the shared packs once.

```

Verify the rig now imports `bead-gate-rig` and not `architect-rig`.

The rig should now import `bead-gate-rig` and no longer import `architect-rig`.

**Copy and paste**

```bash
gc import list --rig ascii-art
```

**Expected output**

```text
bead-gate-rig	packs/bead-gate-rig		(path)
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

Restart the city so the new agent and formula take effect.

**Copy and paste**

```bash
gc restart
```

Confirm everything loaded.

All four formulas should be listed. `mol-architect-review` and `mol-polecat-pr` resolve transitively via `architect-rig` and `pr-gate-rig`.

**Copy and paste**
```bash
gc formula list | grep -E "mol-architect-review|mol-refinery-architect-patrol|mol-polecat-pr|mol-bead-review"
```

**Expected output**

```text
mol-architect-review
mol-bead-review
mol-polecat-pr
mol-refinery-architect-patrol
```

## Try It

### 1. Locate one bead from the first epic

Letters a–g have merged through the base factory. List the remaining open
`Implement <letter>.md` tasks and grab the next one.

**Copy and paste**

```bash
cd "$ASCII_ART_PATH"
bd list --type=task --status=open --limit 0 | grep "Implement [h-j]\.md"
```

Pick `h.md` and capture its ID.

**Copy and paste**

```bash
export BEAD_ID=$(bd list --type=task --status=open --limit 0 | grep -E "Implement h\.md$" | awk '{print $2}')
bd show $BEAD_ID
```

You should see `metadata.target_file=ascii/h.md` and no
`bead_review_passed` field yet — the project-manager will write it
during its first pass.

### 2. Sling the bead at the project-manager (new entry point)

The new entry point is the project-manager. Run from the city
directory.

**Copy and paste**

```bash
cd $FACTORY_PATH
gc sling ascii-art/bead-gate-rig.project-manager $BEAD_ID --on mol-bead-review
```

When this works, you should see the task sent to the project-manager
along with the formula.

**Expected output**

```text
⎿  Auto-convoy aa-0s7
    Attached wisp aa-3ii (formula "mol-bead-review") to aa-ne 1
    Slung aa-nel.1 (with formula "mol-bead-review") → ascii-art/bead-gate-rig.project-manager
```

What this does: the project-manager reads the bead's title,
description, and metadata; walks the conformity checklist
(meaningful title, non-empty description, `target_file` set and
consistent with the title, parent epic exists); and writes a verdict.
For a clean `Implement h.md` bead, the verdict is PASS.

### 3. Watch the project-manager run and the polecat pick up

In another terminal, list the live agent sessions.

**Copy and paste**

```bash
gc session list
```

Attach to follow it live.

**Copy and paste**

```bash
gc session attach <project-manager-session>
```

The project-manager finishes quickly. Confirm the verdict.

**Copy and paste**

```bash
gc bd show $BEAD_ID
```

You should see something like the following.

**Expected output**

```text
○ aa-7ln.13 · Implement h.md   [● P2 · OPEN]

NOTES
project-manager: PASSED. <one-line summary>. Routing to polecat pool.

METADATA
  bead_review_passed: true
  gc.routed_to: ascii-art/bead-gate-rig.polecat
  target_file: ascii/h.md
  ...
```

The bead is back in the polecat pool. The polecat reconciler will
spawn a polecat session next; the polecat pours `mol-polecat-pr`
exactly as in the base factory.

**Copy and paste**

```bash
gc session list
gc session attach <polecat-session>
```

From here, the rest of the pipeline is unchanged from the base factory's architect —
polecat writes the file, hands the bead to the refinery, the
refinery routes to the architect, the architect approves, the
refinery publishes a PR. Wait for the PR and merge as before.

**Copy and paste**

```bash
# Poll until pr_number is populated.
watch -n 5 'gc bd show $BEAD_ID'

# When ready:
cd $ASCII_ART_PATH
export PR=$(BD_JSON_ENVELOPE=1 gc bd show $BEAD_ID --json | jq -r '.data[0].metadata.pr_number')
gh pr view "$PR" --web
gh pr merge "$PR" --merge
```

### 4. Demonstrate the FAIL path

To see the project-manager block a bead, deliberately strip
`target_file` from the next letter and re-sling.

**Copy and paste**

```bash
cd $ASCII_ART_PATH
export BAD_BEAD=$(bd list --type=task --status=open --limit 0 | grep -E "Implement i\.md$" | awk '{print $2}')

# Wipe target_file so the bead fails the task-checklist's
# "target_file is set" check.
bd update $BAD_BEAD --unset-metadata target_file

bd show $BAD_BEAD
# metadata.target_file should be absent.
```

Sling the project-manager at the broken bead.

**Copy and paste**

```bash
cd $FACTORY_PATH
gc sling ascii-art/bead-gate-rig.project-manager $BAD_BEAD --on mol-bead-review
```

Once the project-manager finishes, the bead's status flips and the
verdict is recorded.

**Copy and paste**

```bash
gc bd show $BAD_BEAD
```

**Expected output**

```text
○ aa-7ln.14 · Implement i.md   [● P2 · BLOCKED]

NOTES
project-manager: FAILED. <one-line reason citing the failing check>

METADATA
  bead_review_passed: false
  bead_review_feedback: <one short paragraph>
  ...
```

The status is `BLOCKED`. The polecat pool will not claim this bead.
A mail to the mayor went out at the same time.

You should see a mail with the subject line `Bead blocked at project-manager: <bead-id>`.

**Copy and paste**

```bash
gc mail inbox mayor
```

**Expected output**

```text
ID           FROM                                      SUBJECT                                     BODY
fa-wisp-94s  ascii-art/bead-gate-rig.project-manager   Bead blocked at project-manager: <bead-id>  ...
```

### 5. Unblock the bead by hand and re-sling

Restore the metadata and unblock the bead, then re-sling for a
clean re-review.

**Copy and paste**

```bash
cd $ASCII_ART_PATH
bd update $BAD_BEAD --set-metadata target_file=ascii/i.md
bd update $BAD_BEAD --status=open

cd $FACTORY_PATH
gc sling ascii-art/bead-gate-rig.project-manager $BAD_BEAD --on mol-bead-review
```

This time the project-manager passes the bead and routes it to the
polecat pool. From here, the rest of the pipeline is unchanged. (The
Grill-Me section below introduces a Grill-Me skill in your local agent
so you can refine vague or malformed beads before slinging them at the
project-manager — saves a round-trip.)

### 6. Demonstrate the test-generation gate

The checklist's last task-side check is different in kind from the
others. Checks 4 through 6 ask whether the bead is *complete*;
check 7 asks whether it is *verifiable* — whether the description
names an outcome a test could assert. It is the cheapest place in
the whole factory to catch "nobody said what done looks like",
because it fires before a polecat has written a line.

Make a bead that is well-formed but unverifiable, and watch it get
blocked anyway.

**Copy and paste**

```bash
cd $ASCII_ART_PATH
export VAGUE_BEAD=$(bd create --title "Improve the rendering of j.md" \
  --description "Make the output for j.md nicer and more consistent with the others." \
  --type task --priority 2 --json | jq -r '.id')

bd update $VAGUE_BEAD --set-metadata target_file=ascii/j.md
bd show $VAGUE_BEAD
```

Every earlier check passes. The title is meaningful, the description
is non-empty, `target_file` is set and matches the title. Only the
test-generation check has anything to object to.

**Copy and paste**

```bash
cd $FACTORY_PATH
gc sling ascii-art/bead-gate-rig.project-manager $VAGUE_BEAD --on mol-bead-review
```

**Expected output**

```text
○ aa-7ln.15 · Improve the rendering of j.md   [● P2 · BLOCKED]

NOTES
project-manager: FAILED. The description names no outcome a test could
assert — "nicer" and "more consistent" are not observable.

METADATA
  bead_review_passed: false
  bead_review_feedback: <asks what you would check to confirm this is done>
```

Now answer the question the feedback asked, and re-sling:

**Copy and paste**

```bash
cd $ASCII_ART_PATH
bd update $VAGUE_BEAD --description "Create ascii/j.md containing a 5-line ASCII block for the letter J and a two-line rhyme, matching the line count and front-matter of ascii/i.md."
bd update $VAGUE_BEAD --status=open --unset-metadata bead_review_passed

cd $FACTORY_PATH
gc sling ascii-art/bead-gate-rig.project-manager $VAGUE_BEAD --on mol-bead-review
```

It passes. Nothing about the work changed — only the description of
what done means. That is the whole point of the check, and it is why
this gate is worth more on a real backlog than on `ascii-art`: your
own beads are the ones that say "improve" and "handle better".

### 7. Reflect

That worked. Every bead now passes a conformity check before any
polecat is allowed to start work on it. Malformed beads are blocked
at the front of the factory rather than caught downstream after a
polecat has already written code against a bad spec. The status flip
is the durable signal — the polecat pool ignores blocked beads, so
the gate does not depend on the polecat itself reading
`bead_review_passed`.

What's still missing:

- **The operator has to fix blocked beads by hand.** When a bead
  fails review, the project-manager surfaces the problem — but
  rewording the bead's description, filling in `target_file`, or
  adding a missing parent epic is human work. **The Grill-Me section below — Grill
  Me skill** installs a productivity skill in your local agent that
  walks you through refining a bead by question-and-answer, so the
  next sling at the project-manager is more likely to pass on the
  first try.
- **The conformity checklist is hand-coded for this rig.** A
  different rig (Go service, React app, ML notebook) would want a
  different checklist. **Hardening 1 — Bead-creation formula
  extensions** introduces additional pre-PM agents (Design Lead,
  Test Lead, Doc Lead) that *write* design/test/docs context onto
  beads via custom formulas, so the project-manager has more to
  check by the time it sees the bead.
- **One reviewer, one ADR/docs corpus.** No separate reviewer per
  domain inside the factory. **Hardening 2 — Specialize reviewers
  per domain** splits the architect into ADR, design, testing, and
  docs reviewers running in parallel, with the refinery checking
  approvals from all of them.

## Refining a bead so the gate passes it

The gate is mechanical: it reads what is on the bead and decides pass or fail. It does not write for you. So when a bead is vague — "implement X", no description, no `target_file` — the feedback is "your bead is vague, fix it", and you are left staring at `bd update`.

That is the operator's half of the problem, and it has an operator-side fix that needs no change to the factory at all.

**Grill Me**, by Matt Pocock, is a small productivity skill: a markdown file that teaches your local coding agent to interview you. Instead of sitting in front of a blank bead trying to remember what to fill in, you say "grill me on this bead" and the agent asks the missing questions one at a time. *What file does this write? What does done look like? Which decision record governs it?* Your one-line answers get composed into a bead the gate can pass.

### Install it

**Copy and paste**

```bash
# Clone (or pull) the skills repo somewhere outside the rig.
git clone https://github.com/mattpocock/skills.git ~/grill-me-skill
```

For Claude Code, project-scoped, which is what this tutorial assumes:

**Copy and paste**

```bash
cd "$ASCII_ART_PATH"
mkdir -p .claude/skills/grill-me
cp ~/grill-me-skill/skills/productivity/grill-me/SKILL.md \
   .claude/skills/grill-me/SKILL.md
```

The skill is harness-agnostic — it is free-form markdown — so for any other agent, drop `SKILL.md` wherever that harness loads skills. If yours has no skills primitive, paste the file's contents at the start of a session. Crude, and it works.

Confirm it loaded by asking your agent whether it has the Grill Me skill available.

### Use it on a bead the gate rejected

Take one of the beads the gate blocked above, and instead of guessing at the fix:

> Grill me on this bead: `<the-bead-id>`. Read it with `bd show`, ask me what is missing one question at a time, then write the tightened title and description back with `bd update`.

Then re-sling the gate and watch it pass.

### Make it the default for your team

A line in your rig's agent instructions has more leverage here than any pack patch, because every operator picks it up automatically:

```text
Before slinging a bead at the gate, run the Grill Me skill to fill in the
obvious gaps: target file, deliverable, acceptance check, parent epic.
```

**What to notice.** Nothing in this section changed the factory. The gate is unchanged, no pack was installed, no city restarted. The factory does not know or care that you used a skill; it just sees a better-formed bead arrive. **Not every improvement to a software factory is a change to the software factory** — some of the highest-leverage ones are changes to how work reaches it.


## Verification

The `mol-bead-review` formula is loaded — one row.

**Copy and paste**

```bash
gc formula list | grep mol-bead-review
```

**Expected output**

```text
mol-bead-review
```

The cleared `h.md` bead carries a PASS verdict — look for `metadata.bead_review_passed=true` and a `project-manager: PASSED...` note. After the polecat / refinery / architect chain runs, `pr_url` and `pr_number` should be populated and the file merged.

**Copy and paste**

```bash
gc bd show $BEAD_ID
```

**Expected output**

```text
METADATA
...
  pr_number: 2
  pr_url: https://github.com/<username>/ascii-art/pull/<pr-number>
  refinery_approval_at: <timestamp>
  refinery_approved: true
```

The deliberately-broken bead is blocked. After step 5: `status=blocked`, `bead_review_passed=false`, `bead_review_feedback` set. After step 6: `status=open`, `bead_review_passed=true`.

**Copy and paste**

```bash
gc bd show $BAD_BEAD
```

**Expected output**

```text
METADATA
...
  bead_review_passed: true
  bead_review_feedback: <one short paragraph>
  ...
```

Confirm the new letter on `origin/main`.

**Copy and paste**

```bash
cd $ASCII_ART_PATH
git fetch origin && git pull
git log --oneline origin/main -1
ls ascii/h.md
```

## Troubleshooting

- **`gc formula list` doesn't show `mol-bead-review`.** The
  `bead-gate-rig` pack didn't load. Run `gc import list --rig ascii-art` and confirm you see `bead-gate-rig`. If it's missing,
  re-run `gc import add --rig ascii-art packs/bead-gate-rig` and restart.
- **Project-manager passes a bead but the polecat never picks it up.**
  Check `gc.routed_to` on the bead — it should read
  `ascii-art/<binding-prefix>polecat` (the binding prefix is
  rig-pack-specific; for `bead-gate-rig` running over `architect-rig`
  the prefix may differ). If the `routed_to` value points at a
  non-existent agent, the reconciler will not spawn a polecat. Compare
  against a working bead from the base factory's architect by `gc bd show` after the
  refinery's bounce path fired.
- **Project-manager keeps failing a bead the operator believes is
  fine.** Read `metadata.bead_review_feedback` carefully — it cites
  one specific check. The most common false-positive is rule 3
  ("description names a concrete deliverable") on terse but valid
  descriptions; in that case, lengthen the description by one
  sentence and re-sling.
- **Blocked bead stays blocked even after `bd update --status=open`.**
  Both `status=open` AND `bead_review_passed` matter. The
  project-manager's load-context step early-exits if
  `bead_review_passed=true` is already set, so a bead that was
  blocked, then unblocked, then re-slung will skip the checklist
  unless `bead_review_passed` was unset. Run
  `bd update $BEAD --unset-metadata bead_review_passed` before
  re-slinging if the project-manager is short-circuiting.

## What's next

This is one of six options, and they are a menu rather than a sequence. Every one installs on the base factory alone, so take them in whatever order solves a problem you actually have. The full list is in [the feature labs](../progression/L3-L5-feature-labs.md#the-six-options).

Pairs naturally with the [bead creation Leads](./01-bead-creation-formula-extensions.md), whose specs this gate's checklist can then require before a polecat may claim the bead.

« [back to the feature labs](../progression/L3-L5-feature-labs.md) »
