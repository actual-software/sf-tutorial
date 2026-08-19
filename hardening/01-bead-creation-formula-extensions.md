# Bead Creation Formula Extensions

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context](#context)
- [Walkthrough](#walkthrough)
  - [1. Install the bead-builders-rig pack into factory1](#1-install-the-bead-builders-rig-pack-into-factory1)
  - [2. Pick the next bead](#2-pick-the-next-bead)
  - [3. Sling the three Leads](#3-sling-the-three-leads)
  - [4. Inspect the three spec files and the bead's metadata](#4-inspect-the-three-spec-files-and-the-beads-metadata)
  - [5. Commit the new spec files](#5-commit-the-new-spec-files)
  - [6. Hand the bead to the polecat and watch it read the specs](#6-hand-the-bead-to-the-polecat-and-watch-it-read-the-specs)
  - [7. (Optional) Skip a Lead and watch what the specs were doing](#7-optional-skip-a-lead-and-watch-what-the-specs-were-doing)
  - [8. (Optional) Make the specs mandatory with the bead gate](#8-optional-make-the-specs-mandatory-with-the-bead-gate)
  - [9. Reflect](#9-reflect)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

By the end of this exercise you will have installed the `bead-builders-rig` pack so the `design-lead`, `test-lead`, and `doc-lead` agents draft a design spec, a test plan and a docs outline onto every bead before the polecat starts work.

## Prereqs

- [W3](../progression/W3-run-your-factory.md) complete: the base factory installed on a rig, with the polecat, refinery and architect running.
- `$SFI_PATH` set in your shell. [W2](../progression/W2-cloud-box-and-preflight.md) and [W3](../progression/W3-run-your-factory.md) both append it to a shell rc, so it survives a new terminal. Every other path on this page is written out from it.
- You are inside the rig directory: `cd "$SFI_PATH/ascii-art"`.
- `gh` is authenticated; `jq` is installed.
- An open task bead to work with. `bd list --status open --limit 5` picks one.

**This option needs no other option.** It installs on the base factory, so take it first, last, or on its own. Pairing it with the [bead gate](./06-bead-gate-checks.md) is the natural next step once you have both, because that gate can then require the specs these Leads write.

## Context

Branching/Merging strategy is unchanged from the base factory's architect. What changes here is the *front* of the factory: the rig now ships three "light-side" helper agents — a **Design Lead**, a **Test Lead**, and a **Doc Lead** — each of which produces a focused spec for the work the bead describes. Each spec lands as a file in the rig repo and as a metadata stamp on the bead, so the thinking is written down and addressable before anyone implements anything.

Be clear-eyed about who consumes them today. The specs are written for the operator and for reviewers that go looking for them; the base factory's polecat and architect do not read the three metadata fields by name. The [domain reviewers](./02-specialize-reviewers-per-domain.md) option is the one that does, citing each spec in the matching lane. On its own, this option buys you better-specified work and a record of the decisions, not an enforced contract.

Agent workflow with the Leads in place:

1. The **operator** drafts the bead (or uses the Grill-Me skill from the [bead gate](./06-bead-gate-checks.md) option's Grill-Me section to refine its title and description).
1. The **operator** slings the three Leads at the bead, one at a time:
   - `gc sling <rig>/design-lead <bead> --on mol-design-spec` — drafts `docs/design/<bead-id>.md`, stamps `metadata.design_doc=<path>`.
   - `gc sling <rig>/test-lead <bead> --on mol-test-spec` — drafts `docs/testing/<bead-id>.md`, stamps `metadata.test_plan=<path>`.
   - `gc sling <rig>/doc-lead <bead> --on mol-doc-spec` — drafts `docs/outlines/<bead-id>.md`, stamps `metadata.docs_outline=<path>`.
1. The **polecat / refinery / architect** chain (the base factory) runs exactly as before, and the bead now carries three spec paths through it.

Each Lead stamps its path onto the bead, so anything that wants a spec looks it up in the bead's metadata rather than guessing at a filename. Nothing in the base factory *requires* the specs, and nothing there reads them by name either: a bead without them still moves, and a bead with them moves the same way. What changes is that the design, the test plan and the docs impact are now written down where the operator, a reviewer, or a later option can pick them up.

The Leads do **not** write production code, modify the bead's title or description, or stamp any downstream verdict flags. They are upstream "light-side" helpers — agents whose job is to **shape higher-quality work with less effort**. The operator could have written all three docs by hand; the Leads automate the boring parts and surface trade-offs the operator would otherwise miss.

This page installs the `bead-builders-rig` pack into the `ascii-art` rig. The pack imports the base factory directly, so the polecat / refinery / architect flow you already have keeps working. After a restart, the three Leads (`design-lead`, `test-lead`, `doc-lead`) are registered. You sling the next letter from `letters-a-m` at each Lead in turn, watch the three spec files land under `docs/design/`, `docs/testing/`, `docs/outlines/`, and the matching metadata stamps appear on the bead. Then you hand the bead to the polecat and watch it carry the specs through the run.

Two other options pair well with this one, and neither is required. The [domain reviewers](./02-specialize-reviewers-per-domain.md) option splits the architect into four parallel reviewers, each citing the doc family the matching Lead wrote. The [bead gate](./06-bead-gate-checks.md) option adds a project-manager in front of the polecat, which is the natural place to start requiring the specs rather than merely welcoming them.

## Walkthrough

### 1. Install the bead-builders-rig pack into factory1

The [bead gate](./06-bead-gate-checks.md) option gives the rig a project-manager that gates beads on a small conformity checklist (title, description, `target_file`, parent epic), and its Grill-Me section adds a skill for refining vague beads quickly. What's still missing, with or without that option, is **design / test / docs context on every bead**: the operator types a title and a one-paragraph description, and the polecat is left to guess at the design, the test plan, and the docs impact.

This ships as a single rig-scoped pack, **`bead-builders-rig`**, that adds three new agents and three new formulas:

- `design-lead` (`scope = "rig"`, pool `min=0, max=1`) and `mol-design-spec` — reads the bead and the rig's design docs, drafts `docs/design/<bead-id>.md`, stamps `metadata.design_doc`.
- `test-lead` (`scope = "rig"`, pool `min=0, max=1`) and `mol-test-spec` — reads the bead and the rig's testing docs, drafts `docs/testing/<bead-id>.md`, stamps `metadata.test_plan`.
- `doc-lead` (`scope = "rig"`, pool `min=0, max=1`) and `mol-doc-spec` — reads the bead and the rig's user-facing docs, drafts `docs/outlines/<bead-id>.md`, stamps `metadata.docs_outline`.

Each Lead is independent. Run them in any order. They do not depend on each other; they each take the same inputs (the bead and the relevant doc tree) and produce one focused spec.

The new pack declares one import: `architect-rig` (which transitively brings `pr-gate-rig` and `setup`), so it sits directly on the base factory. It adds three agents and three formulas and patches nothing, which is what lets you install it on its own.

Inspect the pack before installing.

**Copy and paste**

```bash
ls "$SFI_PATH/sf-tutorial/artifacts/packs/bead-builders-rig/"
cat "$SFI_PATH/sf-tutorial/artifacts/packs/bead-builders-rig/pack.toml"
ls "$SFI_PATH/sf-tutorial/artifacts/packs/bead-builders-rig/agents/"
cat "$SFI_PATH/sf-tutorial/artifacts/packs/bead-builders-rig/agents/design-lead/agent.toml"
cat "$SFI_PATH/sf-tutorial/artifacts/packs/bead-builders-rig/formulas/mol-design-spec.formula.toml"
# (similar for test-lead / mol-test-spec and doc-lead / mol-doc-spec)
```

What to notice in the pack:

- **One Lead per discipline.** Each agent owns one doc file under one directory; each formula is a 3-step (load-context → draft-spec → drain) pour. They do not overlap.
- **Light-side, not gates.** The Leads do not block beads or stamp verdicts. A missing spec makes the work thinner, not invalid, and nothing in the base factory turns it into an error.
- **Specs live in the rig repo.** `docs/design/<bead>.md`, `docs/testing/<bead>.md`, `docs/outlines/<bead>.md` — committed alongside source code, so anything that opens them reads them out of the working tree rather than out of the bead.

Copy the pack into the city's `packs/` directory.

**Copy and paste**

```bash
mkdir -p "$SFI_PATH/factory1/packs"

# Delete first: cp -r copies the source *into* the destination when the destination already exists, so a second run would nest the pack.
rm -rf "$SFI_PATH/factory1/packs/bead-builders-rig"

cp -r "$SFI_PATH/sf-tutorial/artifacts/packs/bead-builders-rig" \
      "$SFI_PATH/factory1/packs/bead-builders-rig"
```

Confirm the pack landed flat, with a single `pack.toml` at its top level:

**Copy and paste**

```bash
find "$SFI_PATH/factory1/packs/bead-builders-rig" -name pack.toml
```

**Expected output**

```text
$SFI_PATH/factory1/packs/bead-builders-rig/pack.toml
```

One line is the whole check. A second line ending in `bead-builders-rig/bead-builders-rig/pack.toml` is a nested copy left by an earlier run, and the fix is to delete `$SFI_PATH/factory1/packs/bead-builders-rig` and repeat the copy above. The `gc import list` check below cannot see it, because it reports the path recorded in `pack.toml` rather than what sits inside the directory.

Register the new import at rig scope. Run from the city directory.

**Copy and paste**

```bash
cd "$SFI_PATH/factory1"

gc import add --rig ascii-art "$SFI_PATH/sf-tutorial/artifacts/packs/bead-builders-rig"

# Nothing is removed. This option sits alongside the base factory,
# which keeps its orders and resolves the shared packs once.

```

Verify the imports.

The rig should now import `bead-builders-rig` alongside `base-factory`.

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

Confirm the three formulas loaded.

Three rows should be listed.

**Copy and paste**

```bash
gc formula list \
  | grep -E "mol-(design|test|doc)-spec"
```

**Expected output**

```text
TBD: capture actual terminal output during smoke test
```

### 2. Pick the next bead

Set `$BEAD_ID` to the next open `Implement j.md` task and inspect it.

**Copy and paste**

```bash
cd "$SFI_PATH/ascii-art"
export BEAD_ID=$(bd list --type=task --status=open --limit 0 | grep -E "Implement j\.md$" | awk '{print $2}')
bd show $BEAD_ID
```

You should see the bead's title, description, `target_file`, and no `design_doc`, `test_plan`, or `docs_outline` yet.

### 3. Sling the three Leads

The Leads are independent and can be slung in any order. Run them sequentially for now (you can fan them out in parallel once you trust the flow).

**Copy and paste**

```bash
cd $SFI_PATH/factory1
gc sling ascii-art/bead-builders-rig.design-lead $BEAD_ID --on mol-design-spec
gc sling ascii-art/bead-builders-rig.test-lead   $BEAD_ID --on mol-test-spec
gc sling ascii-art/bead-builders-rig.doc-lead    $BEAD_ID --on mol-doc-spec
```

Each sling spawns a Lead session that reads the bead and the relevant doc tree, drafts a spec, writes it to disk, and stamps the matching metadata field.

Watch the sessions live.

**Copy and paste**

```bash
gc session list
gc session attach <design-lead-session>
#  Repeat for test-lead and doc-lead.
```

### 4. Inspect the three spec files and the bead's metadata

Once all three Leads finish, list and read the spec files.

A file named `$BEAD_ID.md` should be present in each directory.

**Copy and paste**

```bash
cd $SFI_PATH/ascii-art
ls docs/design/ docs/testing/ docs/outlines/
```

**Expected output**

```text
TBD: capture actual terminal output during smoke test
```

**Copy and paste**

```bash
cat docs/design/$BEAD_ID.md
cat docs/testing/$BEAD_ID.md
cat docs/outlines/$BEAD_ID.md
```

Each file follows the section template baked into the matching agent's prompt — design has Deliverable / Approach / Trade-offs / Open questions; testing has What "passing" means / Mechanical checks / Behavioral checks / Out of scope; docs has Doc impact / Per-file outline / No-impact paths.

The bead now carries three new metadata fields.

**Copy and paste**

```bash
gc bd show $BEAD_ID
```

**Expected output**

```text
METADATA
  design_doc:    docs/design/<bead-id>.md
  docs_outline:  docs/outlines/<bead-id>.md
  target_file:   ascii/j.md
  test_plan:     docs/testing/<bead-id>.md
```

### 5. Commit the new spec files

A metadata stamp records a path; it does not publish the file. Anything that opens a spec reads it out of the working tree, so the three files have to land on `main` (or on the polecat's feature branch) before a reader can find them. The simplest path is a small docs-only commit on `main`.

**Copy and paste**

```bash
cd $SFI_PATH/ascii-art
git add docs/design docs/testing docs/outlines
git commit -m "docs(specs): add design/test/docs specs for $BEAD_ID"
git push origin main
```

(In a real flow, the Leads' output could land on a docs branch and go through its own PR review. The simple direct-commit pattern here keeps the lesson focused on the agent flow.)

### 6. Hand the bead to the polecat and watch it read the specs

The bead now carries `design_doc`, `test_plan` and `docs_outline`, each pointing at a file that exists. Hand it to the polecat the same way the base factory does.

**Copy and paste**

```bash
cd $SFI_PATH/factory1
gc sling ascii-art/bead-builders-rig.polecat $BEAD_ID --on mol-polecat-pr
```

Watch the session.

**Copy and paste**

```bash
gc session list
gc session attach <polecat-session>
```

The polecat implements the letter exactly as it does on the base factory. The difference is what the bead is carrying: three spec paths that you, a reviewer, or a paired option can open at any point in the run.

Confirm the specs are on the bead and the work is moving.

**Copy and paste**

```bash
gc bd show $BEAD_ID
```

**Expected output**

```text
status=in_progress, design_doc=docs/design/<bead-id>.md,
test_plan=docs/testing/<bead-id>.md,
docs_outline=docs/outlines/<bead-id>.md,
branch set once the polecat pushes.
```

From here, the polecat / refinery / architect chain runs as in the base factory. Wait for the PR and merge.

**Copy and paste**

```bash
watch -n 5 'gc bd show $BEAD_ID'

cd $SFI_PATH/ascii-art
export PR=$(BD_JSON_ENVELOPE=1 gc bd show $BEAD_ID --json | jq -r '.data[0].metadata.pr_number')
gh pr view "$PR" --web
gh pr merge "$PR" --merge
```

### 7. (Optional) Skip a Lead and watch what the specs were doing

To feel what the specs buy you, run only two of the three Leads on the next letter and let it through with no docs outline.

**Copy and paste**

```bash
cd $SFI_PATH/ascii-art
export PARTIAL_BEAD=$(bd list --type=task --status=open --limit 0 | grep -E "Implement k\.md$" | awk '{print $2}')

cd $SFI_PATH/factory1
gc sling ascii-art/bead-builders-rig.design-lead $PARTIAL_BEAD --on mol-design-spec
gc sling ascii-art/bead-builders-rig.test-lead   $PARTIAL_BEAD --on mol-test-spec
# Skip doc-lead deliberately.

gc sling ascii-art/bead-builders-rig.polecat $PARTIAL_BEAD --on mol-polecat-pr
```

Once the polecat finishes, inspect the bead.

**Copy and paste**

```bash
gc bd show $PARTIAL_BEAD
```

**Expected output**

```text
design_doc and test_plan set, docs_outline absent.
The polecat still implements the letter and pushes a branch.
```

Nothing blocks. The bead moves with two specs instead of three, and the missing outline shows up as thinner documentation rather than as an error. That is the honest shape of this option on its own: the Leads make work better, they do not make it mandatory. Run the Doc Lead now if you want the third spec on the record.

**Copy and paste**

```bash
cd $SFI_PATH/factory1
gc sling ascii-art/bead-builders-rig.doc-lead $PARTIAL_BEAD --on mol-doc-spec
cd $SFI_PATH/ascii-art
git add docs/outlines && git commit -m "docs(specs): outline for $PARTIAL_BEAD" && git push
```

### 8. (Optional) Make the specs mandatory with the bead gate

Turning "better" into "required" needs a gate in front of the polecat, and that is a different option. Install the [bead gate](./06-bead-gate-checks.md) alongside this one and you get a project-manager that refuses malformed beads before a polecat may claim them.

**Copy and paste**

```bash
cd $SFI_PATH/factory1
gc sling ascii-art/bead-gate-rig.project-manager $BEAD_ID --on mol-bead-review
```

Note the address: the project-manager belongs to `bead-gate-rig`, so you name that pack even though you installed this one too. Out of the box its checklist covers title, description, `target_file` and parent epic; it does not yet look for the three spec fields. Extending it to require `design_doc`, `test_plan` and `docs_outline` is a genuinely good exercise once you have both options installed, and it is the shortest path from this tutorial to a gate you actually want.

### 9. Reflect

That worked. Every bead now reaches the polecat with three small specs already drafted: design, testing, docs. Operators don't have to remember to write each one; the Leads automate the boring parts and surface the trade-offs that need a human decision (the "Open questions" section in the design spec is where this lands). The specs are an invitation rather than a rule — nothing rejects a bead that lacks them until you add a gate that does.

What's still missing:

- **One reviewer at the back, four specs at the front.** The architect (the base factory's architect) reviews against the rig's full doc corpus — but it doesn't have a separate lens per discipline. **Hardening 2 — Specialize reviewers per domain** splits the architect into four parallel reviewers (ADR, design, testing, docs), each citing the doc family the matching Lead authored.
- **No depth-of-review on architecture principles.** Architecture is binary at the architect — approve or reject. **Hardening 3 — Architecture-best-practices loop** introduces a per-bead score against 23 canonical principles with an append-only audit trail.
- **Solo provider.** Every reviewer agent in the rig runs against the same model. **Hardening 4 — Strengthen the review system** fans out to vendor-diverse reviewers plus a synthesizer.

## Verification

Confirm the three new formulas loaded.

Three rows should be listed.

**Copy and paste**

```bash
gc formula list | grep -E "mol-(design|test|doc)-spec"
```

**Expected output**

```text
TBD: capture actual terminal output during smoke test
```

After running the three Leads on `$BEAD_ID`, the spec files exist and the bead carries the matching metadata.

All three metadata fields should be set and all three files should exist.

**Copy and paste**

```bash
ls docs/design/$BEAD_ID.md docs/testing/$BEAD_ID.md docs/outlines/$BEAD_ID.md
gc bd show $BEAD_ID | grep -E "design_doc|test_plan|docs_outline"
```

**Expected output**

```text
TBD: capture actual terminal output during smoke test
```

Project-manager passes the bead with all three specs in place.

`bead_review_passed=true` should be set on the bead.

**Copy and paste**

```bash
gc bd show $BEAD_ID | grep bead_review_passed
```

**Expected output**

```text
TBD: capture actual terminal output during smoke test
```

Project-manager blocks a bead missing one spec (step 7).

**Copy and paste**

```bash
gc bd show $PARTIAL_BEAD | grep -E "status|bead_review"
# Initially: status=blocked, bead_review_passed=false. After fixing,
# status=open, bead_review_passed=true.
```

Letter on `origin/main`.

**Copy and paste**

```bash
git fetch origin && git pull
ls ascii/j.md
```

## Troubleshooting

- **`gc formula list` doesn't show `mol-design-spec` etc.** The `bead-builders-rig` pack didn't load. Run `gc import list --rig ascii-art` and confirm `bead-builders-rig` is present. If missing, re-run `gc import add --rig ascii-art packs/bead-builders-rig` and restart.
- **Lead writes the spec file but doesn't stamp metadata.** Most often the agent finished writing the file but the `gc bd update --set-metadata` call errored (e.g., the bead doesn't exist with that ID). Inspect the session log and re-run the metadata stamp by hand if needed.
- **A downstream agent can't find the spec the metadata names.** The stamp records a path; it does not commit the file. If `metadata.design_doc=docs/design/foo.md` but the reader works from `main` and the spec is still uncommitted, it sees nothing. Commit the spec files before handing the bead on, which is what step 5 is for.
- **Lead writes a spec and nothing downstream mentions it.** Expected on the base factory, which does not read the three fields by name. Install the [domain reviewers](./02-specialize-reviewers-per-domain.md) option to get agents that cite them, or teach your own polecat prompt to open `metadata.design_doc` in a custom pack.
- **`<coordinator>` mail bounces.** Same caveat as earlier pages: substitute your operator handle (for example `mayor`), or accept the no-op in solo mode.

## What's next

This is one of six options, and they are a menu rather than a sequence. Every one installs on the base factory alone, so take them in whatever order solves a problem you actually have. The full list is in [the feature labs](../progression/L3-L5-feature-labs.md#the-six-options).

Pairs naturally with the [bead gate](./06-bead-gate-checks.md), whose checklist can then require the specs these Leads write, and with the [domain reviewers](./02-specialize-reviewers-per-domain.md), whose design, testing and docs lanes read them.

« [back to the feature labs](../progression/L3-L5-feature-labs.md) »
