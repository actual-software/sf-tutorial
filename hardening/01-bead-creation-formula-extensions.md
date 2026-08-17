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
  - [6. Sling the project-manager and watch it pass](#6-sling-the-project-manager-and-watch-it-pass)
  - [7. (Optional) Demonstrate the project-manager rejecting a bead missing one Lead's output](#7-optional-demonstrate-the-project-manager-rejecting-a-bead-missing-one-leads-output)
  - [8. Reflect](#8-reflect)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

By the end of this exercise you will have installed the `bead-builders-rig` pack so the `design-lead`, `test-lead`, and `doc-lead` agents draft per-bead specs and the project-manager's extended checklist enforces that all three specs exist before a bead reaches the polecat.

## Prereqs

- [W3](../progression/W3-run-your-factory.md) complete: the base factory installed on a rig, with the polecat, refinery and architect running.
- You are inside the rig directory, with `$FACTORY_PATH`, `$ASCII_ART_PATH`, `$TUTORIAL_PATH` and `$ARTIFACTS_PATH` exported, then `cd "$ASCII_ART_PATH"`.
- `gh` is authenticated; `jq` is installed.
- An open task bead to work with. `bd list --status open --limit 5` picks one.

**This option needs no other option.** It installs on the base factory, so take it first, last, or on its own. Pairing it with the [bead gate](./06-bead-gate-checks.md) is the natural next step once you have both, because that gate can then require the specs these Leads write.

## Context

Branching/Merging strategy is unchanged from page 04. What changes here is the *front* of the factory: in addition to the project-manager (the gate that decides whether a bead is well-formed enough for a polecat to start), the rig now ships three "light-side" helper agents — a **Design Lead**, a **Test Lead**, and a **Doc Lead** — each of which produces a focused spec for the work the bead describes. The polecat reads those specs at implement time; the project-manager's checklist (extended in this hardening) requires them to exist before a bead is allowed through.

Agent workflow with the Leads in place:

1. The **operator** drafts the bead (or uses the Grill-Me skill from page 05.2 to refine its title and description).
1. The **operator** slings the three Leads at the bead, one at a time:
   - `gc sling <rig>/design-lead <bead> --on mol-design-spec` — drafts `docs/design/<bead-id>.md`, stamps `metadata.design_doc=<path>`.
   - `gc sling <rig>/test-lead <bead> --on mol-test-spec` — drafts `docs/testing/<bead-id>.md`, stamps `metadata.test_plan=<path>`.
   - `gc sling <rig>/doc-lead <bead> --on mol-doc-spec` — drafts `docs/outlines/<bead-id>.md`, stamps `metadata.docs_outline=<path>`.
1. The **project-manager** (page 05.1, with an extended checklist): in addition to the conformity checks from 05.1, the project-manager now refuses to pass a bead unless `design_doc`, `test_plan`, and `docs_outline` are all set on the bead and point at files that exist on disk.
1. The **polecat / refinery / architect** chain (pages 01–04) runs exactly as before. The polecat reads the three specs at implement time. The architect (page 04) references them during architecture review.

The Leads do **not** write production code, modify the bead's title or description, or stamp any downstream verdict flags. They are upstream "light-side" helpers — agents whose job is to **shape higher-quality work with less effort**. The operator could have written all three docs by hand; the Leads automate the boring parts and surface trade-offs the operator would otherwise miss.

This page installs the `bead-builders-rig` pack into the `ascii-art` rig (removing `bead-gate-rig` from the rig's direct imports — the new pack imports it transitively, so the project-manager / architect / refinery flow remains available). After a restart, the three Leads (`design-lead`, `test-lead`, `doc-lead`) are registered and the project-manager's extended checklist takes effect. You sling the next letter from `letters-a-m` at each Lead in turn, watch the three spec files land under `docs/design/`, `docs/testing/`, `docs/outlines/`, and the matching metadata stamps appear on the bead. Then sling the project-manager and watch it pass on the first try because the new metadata is in place.

The next page (Hardening 2) builds on these spec files: the architect (currently a single agent) splits into four parallel domain reviewers — ADR, design, testing, docs — each citing the doc family the matching Lead wrote.

## Walkthrough

### 1. Install the bead-builders-rig pack into factory1

The page 05.1 setup gave the rig a project-manager that gates beads on a small conformity checklist (title, description, `target_file`, parent epic). The page 05.2 walkthrough added the Grill-Me skill so the operator can refine vague beads quickly. What's still missing is **design / test / docs context on every bead**: the operator types a title and a one-paragraph description, and the polecat is left to guess at the design, the test plan, and the docs impact.

This ships as a single rig-scoped pack, **`bead-builders-rig`**, that adds three new agents and three new formulas:

- `design-lead` (`scope = "rig"`, pool `min=0, max=1`) and `mol-design-spec` — reads the bead and the rig's design docs, drafts `docs/design/<bead-id>.md`, stamps `metadata.design_doc`.
- `test-lead` (`scope = "rig"`, pool `min=0, max=1`) and `mol-test-spec` — reads the bead and the rig's testing docs, drafts `docs/testing/<bead-id>.md`, stamps `metadata.test_plan`.
- `doc-lead` (`scope = "rig"`, pool `min=0, max=1`) and `mol-doc-spec` — reads the bead and the rig's user-facing docs, drafts `docs/outlines/<bead-id>.md`, stamps `metadata.docs_outline`.

Each Lead is independent. Run them in any order. They do not depend on each other; they each take the same inputs (the bead and the relevant doc tree) and produce one focused spec.

The new pack declares one import: `bead-gate-rig` (which transitively brings `architect-rig`, `pr-gate-rig`, and `setup`). The project-manager's prompt is patched in this pack so the existing conformity checklist also requires `metadata.design_doc`, `metadata.test_plan`, and `metadata.docs_outline` to be set and to point at files that exist on disk.

Inspect the pack before installing.

**Copy and paste**

```bash
ls "$ARTIFACTS_PATH/packs/bead-builders-rig/"
cat "$ARTIFACTS_PATH/packs/bead-builders-rig/pack.toml"
ls "$ARTIFACTS_PATH/packs/bead-builders-rig/agents/"
cat "$ARTIFACTS_PATH/packs/bead-builders-rig/agents/design-lead/agent.toml"
cat "$ARTIFACTS_PATH/packs/bead-builders-rig/formulas/mol-design-spec.formula.toml"
# (similar for test-lead / mol-test-spec and doc-lead / mol-doc-spec)
```

What to notice in the pack:

- **One Lead per discipline.** Each agent owns one doc file under one directory; each formula is a 3-step (load-context → draft-spec → drain) pour. They do not overlap.
- **Light-side, not gates.** The Leads do not block beads or stamp verdicts. If a Lead's output is missing, the project-manager catches it at the next bead-review pass (with extended checklist).
- **Specs live in the rig repo.** `docs/design/<bead>.md`, `docs/testing/<bead>.md`, `docs/outlines/<bead>.md` — committed alongside source code, so the architect (page 04) and the polecat both read them out of the working tree.

Copy the pack into the city's `packs/` directory.

**Copy and paste**

```bash
mkdir -p "$FACTORY_PATH/packs"

# Delete first: cp -r copies the source *into* the destination when the destination already exists, so a second run would nest the pack.
rm -rf "$FACTORY_PATH/packs/bead-builders-rig"

cp -r "$ARTIFACTS_PATH/packs/bead-builders-rig" \
      "$FACTORY_PATH/packs/bead-builders-rig"
```

Confirm the pack landed flat, with a single `pack.toml` at its top level:

**Copy and paste**

```bash
find "$FACTORY_PATH/packs/bead-builders-rig" -name pack.toml
```

**Expected output**

```text
$FACTORY_PATH/packs/bead-builders-rig/pack.toml
```

One line is the whole check. A second line ending in `bead-builders-rig/bead-builders-rig/pack.toml` is a nested copy left by an earlier run, and the fix is to delete `$FACTORY_PATH/packs/bead-builders-rig` and repeat the copy above. The `gc import list` check below cannot see it, because it reports the path recorded in `pack.toml` rather than what sits inside the directory.

Register the new import at rig scope and remove the now-redundant direct `bead-gate-rig` import. Run from the city directory.

**Copy and paste**

```bash
cd "$FACTORY_PATH"

gc import add --rig ascii-art "$ARTIFACTS_PATH/packs/bead-builders-rig"

# Nothing is removed. This option sits alongside the base factory,
# which keeps its orders and resolves the shared packs once.

```

Verify the imports.

The rig should now import `bead-builders-rig` and no longer import `bead-gate-rig`.

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

Four rows should be listed.

**Copy and paste**

```bash
gc formula list \
  | grep -E "mol-(design|test|doc)-spec|mol-bead-review"
```

**Expected output**

```text
TBD: capture actual terminal output during smoke test
```

### 2. Pick the next bead

Set `$BEAD_ID` to the next open `Implement j.md` task and inspect it.

**Copy and paste**

```bash
cd "$ASCII_ART_PATH"
export BEAD_ID=$(bd list --type=task --status=open --limit 0 | grep -E "Implement j\.md$" | awk '{print $2}')
bd show $BEAD_ID
```

You should see the bead's title, description, `target_file`, and no `design_doc`, `test_plan`, or `docs_outline` yet.

### 3. Sling the three Leads

The Leads are independent and can be slung in any order. Run them sequentially for now (you can fan them out in parallel once you trust the flow).

**Copy and paste**

```bash
cd $FACTORY_PATH
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
cd $ASCII_ART_PATH
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

The polecat and architect both read these files out of the working tree. They have to land on `main` (or be picked up on the polecat's feature branch) before the polecat reads them. The simplest path is a small docs-only commit on `main`.

**Copy and paste**

```bash
cd $ASCII_ART_PATH
git add docs/design docs/testing docs/outlines
git commit -m "docs(specs): add design/test/docs specs for $BEAD_ID"
git push origin main
```

(In a real flow, the Leads' output could land on a docs branch and go through its own PR review. The simple direct-commit pattern here keeps the lesson focused on the agent flow.)

### 6. Sling the project-manager and watch it pass

The bead now satisfies the extended checklist — title, description, `target_file`, parent epic, **plus** `design_doc`, `test_plan`, and `docs_outline` all set and pointing at files that exist.

**Copy and paste**

```bash
cd $FACTORY_PATH
gc sling ascii-art/bead-builders-rig.project-manager $BEAD_ID --on mol-bead-review
```

Watch the session.

**Copy and paste**

```bash
gc session list
gc session attach <project-manager-session>
```

Confirm the verdict.

**Copy and paste**

```bash
gc bd show $BEAD_ID
```

**Expected output**

```text
status=open, bead_review_passed=true,
gc.routed_to=<rig>/<binding-prefix>polecat,
notes include "project-manager: PASSED..."
```

From here, the polecat / refinery / architect chain runs as in pages 01–04. Wait for the PR and merge.

**Copy and paste**

```bash
watch -n 5 'gc bd show $BEAD_ID'

cd $ASCII_ART_PATH
export PR=$(BD_JSON_ENVELOPE=1 gc bd show $BEAD_ID --json | jq -r '.data[0].metadata.pr_number')
gh pr view "$PR" --web
gh pr merge "$PR" --merge
```

### 7. (Optional) Demonstrate the project-manager rejecting a bead missing one Lead's output

To see the extended checklist enforce, skip one Lead and watch the project-manager block. Pick the next letter and only run two of the three Leads.

**Copy and paste**

```bash
cd $ASCII_ART_PATH
export PARTIAL_BEAD=$(bd list --type=task --status=open --limit 0 | grep -E "Implement k\.md$" | awk '{print $2}')

cd $FACTORY_PATH
gc sling ascii-art/bead-builders-rig.design-lead $PARTIAL_BEAD --on mol-design-spec
gc sling ascii-art/bead-builders-rig.test-lead   $PARTIAL_BEAD --on mol-test-spec
# Skip doc-lead deliberately.

gc sling ascii-art/bead-builders-rig.project-manager $PARTIAL_BEAD --on mol-bead-review
```

Once the project-manager finishes, inspect the bead.

**Copy and paste**

```bash
gc bd show $PARTIAL_BEAD
```

**Expected output**

```text
status=blocked, bead_review_passed=false,
bead_review_feedback citing missing docs_outline.
```

The project-manager surfaces the missing `docs_outline` to the operator. Run the Doc Lead, commit the outline file, unset `bead_review_passed`, and re-sling the project-manager — it will pass.

**Copy and paste**

```bash
cd $FACTORY_PATH
gc sling ascii-art/bead-builders-rig.doc-lead $PARTIAL_BEAD --on mol-doc-spec
cd $ASCII_ART_PATH
git add docs/outlines && git commit -m "docs(specs): outline for $PARTIAL_BEAD" && git push
bd update $PARTIAL_BEAD --status=open --unset-metadata bead_review_passed
cd $FACTORY_PATH
gc sling ascii-art/bead-builders-rig.project-manager $PARTIAL_BEAD --on mol-bead-review
```

(You can leave `k.md` in the polecat queue; it'll be picked up next.)

### 8. Reflect

That worked. Every bead now reaches the polecat with three small specs already drafted: design, testing, docs. Operators don't have to remember to write each one; the Leads automate the boring parts and surface the trade-offs that need a human decision (the "Open questions" section in the design spec is where this lands). The project-manager's extended checklist makes the specs non-optional — a bead without all three won't pass the gate.

What's still missing:

- **One reviewer at the back, four specs at the front.** The architect (page 04) reviews against the rig's full doc corpus — but it doesn't have a separate lens per discipline. **Hardening 2 — Specialize reviewers per domain** splits the architect into four parallel reviewers (ADR, design, testing, docs), each citing the doc family the matching Lead authored.
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
- **Project-manager rejects despite all three metadata fields set.** The extended checklist also requires the file each metadata field points at to **exist on disk**. If `metadata.design_doc=docs/design/foo.md` but `docs/design/foo.md` is missing (e.g., not yet committed and the project-manager is reading from `main`), the gate fires. Either commit the spec files first, or have the project-manager read from the working tree.
- **Lead writes a spec but the polecat ignores it.** The polecat reads the spec file paths off the bead's metadata at implement time. Confirm the polecat session log mentions reading `docs/design/<bead>.md` etc. If the polecat's prompt isn't yet taught to read these files, you may need to update the polecat prompt template in a custom pack — that's a Hardening 2-and-up customization.
- **`<coordinator>` mail bounces.** Same caveat as earlier pages: substitute your operator handle (for example `mayor`), or accept the no-op in solo mode.

## What's next

This is one of six options, and they are a menu rather than a sequence. Every one installs on the base factory alone, so take them in whatever order solves a problem you actually have. The full list is in [the feature labs](../progression/L3-L5-feature-labs.md#the-six-options).

Pairs naturally with the [bead gate](./06-bead-gate-checks.md), whose checklist can then require the specs these Leads write, and with the [domain reviewers](./02-specialize-reviewers-per-domain.md), whose design, testing and docs lanes read them.

« [back to the feature labs](../progression/L3-L5-feature-labs.md) »
