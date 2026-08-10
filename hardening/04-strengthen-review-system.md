# Strengthen the Review System

## Contents

- [Objectives](#objectives)
- [Prereqs](#prereqs)
- [Context](#context)
- [Walkthrough](#walkthrough)
  - [1. Install the multi-vendor-rig pack into factory1](#1-install-the-multi-vendor-rig-pack-into-factory1)
  - [2. Sling a clean bead through the standard pipeline up to the polecat](#2-sling-a-clean-bead-through-the-standard-pipeline-up-to-the-polecat)
  - [3. Sling the three vendor reviewers in parallel](#3-sling-the-three-vendor-reviewers-in-parallel)
  - [4. Sling the synthesizer](#4-sling-the-synthesizer)
  - [5. Sling the other three lanes and watch the refinery aggregate](#5-sling-the-other-three-lanes-and-watch-the-refinery-aggregate)
  - [6. Demonstrate vendor disagreement on a deliberately weak bead](#6-demonstrate-vendor-disagreement-on-a-deliberately-weak-bead)
  - [7. Reflect — Tutorial complete](#7-reflect--tutorial-complete)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objectives

By the end of this exercise you will have:

- The `multi-vendor-rig` pack installed into the `ascii-art` rig, with `principles-loop-rig` removed from the rig's direct imports (it loads transitively).
- Three CLI providers (`codex`, `claude`, `gemini`) verified as installed and authenticated on the host.
- A clean bead carried through the standard pipeline (Leads → `project-manager` → `polecat`), then reviewed by three vendor-pinned reviewers in parallel and fused by a `synthesizer`.
- A deliberately weak bead that exercises vendor disagreement, the synthesizer's majority rule, and the refinery's bounce path.

## Prereqs

- Hardening 3 complete: `principles-loop-rig` is installed, the per-principle audit trail is wired, and at least one bead has been through the principles loop end-to-end.
- **Three CLI providers** installed and authenticated on the host running the pool: `codex`, `claude`, `gemini`. Each provider is installed separately; check the Gas City installation docs (or each provider's own docs) for current install instructions. Verify each:

  **Copy and paste**

  ```bash
  codex --version
  claude --version
  gemini --version
  ```

  If any provider is missing, you can either skip H4 and stay on the single-vendor flow, or run with two providers (majority rule still works at 2/2; at 1/1 the synthesizer always says `false` — see Troubleshooting).
- You're inside the rig directory. If a fresh shell, re-export `$FACTORY_PATH`, `$ASCII_ART_PATH`, `$TUTORIAL_PATH`, and `$ARTIFACTS_PATH` per [00.3](../progression/00.3-setup-foundation.md), then:

  **Copy and paste**

  ```bash
  cd "$ASCII_ART_PATH"
  ```
- `gh` is authenticated; `jq` is installed.
- Letters consumed so far: a–m. The next two open task beads are `Implement n.md` (clean sanity check) and `Implement o.md` (the weak-bead demo).

## Context

Branching/merging strategy is unchanged from page 04. What changes here is the *vendor diversity* of the ADR-lane review. The single `adr-reviewer` (H2) — and its principles-loop variant (H3) — runs against whichever model your harness pins. A single LLM is a single point of view; the cheapest way to harden a code review is to ask two more reviewers who were trained differently and synthesize their answers. This page does exactly that: three vendor-pinned reviewer agents (`reviewer-codex`, `reviewer-claude`, `reviewer-gemini`) run in parallel against the same diff and the same ADR corpus; a `synthesizer` agent reads all three verdicts and applies majority rule.

Agent workflow with the multi-vendor fan-out in place:

1. The **operator** runs the H1 Leads, `project-manager`, and `polecat` as in earlier hardening pages. (Unchanged.)
1. The **polecat** publishes a feature branch and reassigns to the refinery. (Unchanged.)
1. The **operator** slings the three vendor reviewers at the bead in parallel:

   **Example**

   ```bash
   gc sling <rig>/reviewer-codex  <bead> --on mol-vendor-codex-review
   gc sling <rig>/reviewer-claude <bead> --on mol-vendor-claude-review
   gc sling <rig>/reviewer-gemini <bead> --on mol-vendor-gemini-review
   ```

   Each reviewer reads the same diff and the same ADR corpus, then stamps its own `vendor_<name>_approved` and (on rejection) `vendor_<name>_feedback` on the bead. The three sessions run in parallel — independence is the point; the rubric is identical across vendors, only the underlying model differs.
1. Once all three have stamped, the **operator** slings the synthesizer:

   **Example**

   ```bash
   gc sling <rig>/synthesizer <bead> --on mol-synthesize-reviews
   ```

   The synthesizer reads the three verdicts, applies majority rule (≥ 2 of 3 approve → `adr_approved=true`; otherwise `false`), and writes a one-paragraph `synthesizer_summary` distilling points of agreement and disagreement.
1. The **refinery** (H2's `verify-reviewers` step) reads the `adr_approved` value the synthesizer wrote, alongside `design_approved`, `testing_approved`, `docs_approved` from the other three lanes — and aggregates as before. From the refinery's point of view, the ADR lane looks the same as it did in H2; the fan-out is invisible to it.
1. The **merger** (human, plus branch protection from page 03) reads the four-lane verdict trail (with `synthesizer_summary` as the most useful single artifact for the ADR lane) and clicks **Merge**.

The vendor reviewers do **not** push code, share state with each other, or write to the cross-vendor `adr_approved` field. The synthesizer does **not** read the diff; it only fuses what the three vendors wrote.

## Walkthrough

### 1. Install the multi-vendor-rig pack into factory1

H3 added depth along the ADR lane (per-principle scoring) but the scoring still came from a single vendor. A second-opinion review from an independent model would catch principle-scoring blind spots and surface honest disagreements about what "compliant" means.

This ships as a single rig-scoped pack, **`multi-vendor-rig`**, that fans out the ADR lane:

- Three new rig-scoped reviewer agents (`reviewer-codex`, `reviewer-claude`, `reviewer-gemini`), each with its `provider` field pinned to a different CLI / API. The three agents share one prompt template — same rubric, same output contract; only the model differs.
- A new `synthesizer` agent that reads the three vendor verdicts and applies majority rule.
- Four new formulas: three vendor reviewer formulas (`mol-vendor-codex-review`, `mol-vendor-claude-review`, `mol-vendor-gemini-review`) and one synthesis formula (`mol-synthesize-reviews`).

The H2 refinery's `verify-reviewers` step is **unchanged**. The synthesizer writes `adr_approved` (true or false) — the same field the H2 `adr-reviewer` wrote — so from the refinery's point of view the ADR lane looks identical to H2. Manual sling is the entry point in this lesson; auto-dispatch from the refinery (so the operator doesn't have to remember to sling four reviewers per bead) is left as a final exercise.

The other three domain lanes (design, testing, docs) continue to use their H2 single-vendor reviewers. Multi-vendor fan-out for those lanes follows the same pattern as the ADR lane and is left as an exercise.

Inspect the pack:

**Copy and paste**

```bash
ls "$ARTIFACTS_PATH/packs/multi-vendor-rig/"
cat "$ARTIFACTS_PATH/packs/multi-vendor-rig/pack.toml"
ls "$ARTIFACTS_PATH/packs/multi-vendor-rig/agents/"
cat "$ARTIFACTS_PATH/packs/multi-vendor-rig/agents/reviewer-codex/agent.toml"
cat "$ARTIFACTS_PATH/packs/multi-vendor-rig/agents/shared/vendor-reviewer.template.md"
cat "$ARTIFACTS_PATH/packs/multi-vendor-rig/agents/synthesizer/prompt.template.md"
```

What to notice:

- **Three identical rubrics.** The shared `vendor-reviewer.template.md` is loaded by all three vendor agents. They differ only in `provider`. Identical rubric is deliberate: only the model varies, not the read.
- **Synthesizer is not a fourth reviewer.** Its prompt explicitly says "do NOT read the diff yourself." It reads only what the three vendors stamped.
- **Majority rule, no synthesis-by-LLM tricks.** The synthesizer counts `true` verdicts; ≥ 2 of 3 stamps `adr_approved=true`. The one-paragraph `synthesizer_summary` is for the operator's benefit; the gate is the count.

Copy the pack into the city's pack directory:

**Copy and paste**

```bash
cp -r "$ARTIFACTS_PATH/packs/multi-vendor-rig" \
      "$FACTORY_PATH/.gc/system/packs/multi-vendor-rig"
```

Register the new import at rig scope:

**Copy and paste**

```bash
cd "$FACTORY_PATH"

gc import add --rig ascii-art .gc/system/packs/multi-vendor-rig
gc import remove --rig ascii-art principles-loop-rig
```

The rig should now import `multi-vendor-rig` and no longer import `principles-loop-rig`.

**Copy and paste**

```bash
gc import list --rig ascii-art
```

**Expected output**

```text
TBD: capture actual terminal output during smoke test
```

Restart and confirm the new formulas loaded — four rows.

**Copy and paste**

```bash
gc restart

gc formula list \
  | grep -E "mol-vendor-(codex|claude|gemini)-review|mol-synthesize-reviews"
```

**Expected output**

```text
TBD: capture actual terminal output during smoke test
```

### 2. Sling a clean bead through the standard pipeline up to the polecat

Same recipe as Hardening 1 / 2 / 3 up through the polecat publishing a branch.

**Copy and paste**

```bash
cd "$ASCII_ART_PATH"
export BEAD_ID=$(bd list --type=task --status=open --limit 0 | grep -E "Implement n\.md$" | awk '{print $2}')

cd $FACTORY_PATH
gc sling ascii-art/multi-vendor-rig.design-lead $BEAD_ID --on mol-design-spec
gc sling ascii-art/multi-vendor-rig.test-lead   $BEAD_ID --on mol-test-spec
gc sling ascii-art/multi-vendor-rig.doc-lead    $BEAD_ID --on mol-doc-spec
cd $ASCII_ART_PATH
git add docs/design docs/testing docs/outlines && git commit -m "docs(specs): pre-PM specs for $BEAD_ID" && git push origin main

cd $FACTORY_PATH
gc sling ascii-art/multi-vendor-rig.project-manager $BEAD_ID --on mol-bead-review
# Wait for PASS; polecat picks up; refinery picks up.
watch -n 5 'gc bd show $BEAD_ID | grep -E "branch|pr_url|_approved"'
```

When the polecat has pushed a branch and the bead is back at the refinery (with `adr_approved` and the other three lane fields all unset), proceed to step 3.

### 3. Sling the three vendor reviewers in parallel

Run all three slings without waiting between them. Each spawns a separate session against a different model.

**Copy and paste**

```bash
cd $FACTORY_PATH
gc sling ascii-art/multi-vendor-rig.reviewer-codex  $BEAD_ID --on mol-vendor-codex-review
gc sling ascii-art/multi-vendor-rig.reviewer-claude $BEAD_ID --on mol-vendor-claude-review
gc sling ascii-art/multi-vendor-rig.reviewer-gemini $BEAD_ID --on mol-vendor-gemini-review
```

Watch:

You should see three reviewer sessions running concurrently.

**Copy and paste**

```bash
gc session list
```

**Expected output**

```text
TBD: capture actual terminal output during smoke test
```

Optionally attach to one:

**Copy and paste**

```bash
gc session attach <reviewer-codex-session>
```

Watch the bead's metadata flip as each vendor stamps its verdict:

**Copy and paste**

```bash
watch -n 5 'gc bd show $BEAD_ID | grep -E "vendor_"'
```

You should see three pairs of fields appear, one pair per vendor:

**Expected output**

```text
vendor_codex_approved:    true
vendor_claude_approved:   true
vendor_gemini_approved:   false
vendor_gemini_feedback:   <feedback citing one ADR rule>
```

The order they finish is non-deterministic. Ordering doesn't matter for the synthesizer; only the count.

### 4. Sling the synthesizer

After all three vendors have stamped, sling the synthesizer.

**Copy and paste**

```bash
cd $FACTORY_PATH
gc sling ascii-art/multi-vendor-rig.synthesizer $BEAD_ID --on mol-synthesize-reviews
```

Watch:

**Copy and paste**

```bash
gc session list
gc session attach <synthesizer-session>
```

The synthesizer reads the three verdicts, computes the count, and stamps `adr_approved` plus `synthesizer_summary`:

**Copy and paste**

```bash
gc bd show $BEAD_ID | grep -E "adr_approved|synthesizer_summary"
```

Expected on a 2-of-3 approve case:

**Expected output**

```text
adr_approved:           true
synthesizer_summary:    Codex and Claude approve. Gemini rejected
                        citing ADR-0001 rule 3 (line width). Codex
                        and Claude explicitly read line width as
                        compliant; the rejecting reviewer cited the
                        same rule with a stricter interpretation.
                        Forwarding as approved per majority.
```

### 5. Sling the other three lanes and watch the refinery aggregate

Run the three single-vendor lane reviewers from H2 (manually, or let the refinery's `verify-reviewers` auto-dispatch them).

**Copy and paste**

```bash
cd $FACTORY_PATH
gc sling ascii-art/multi-vendor-rig.design-reviewer  $BEAD_ID --on mol-design-review
gc sling ascii-art/multi-vendor-rig.testing-reviewer $BEAD_ID --on mol-testing-review
gc sling ascii-art/multi-vendor-rig.docs-reviewer    $BEAD_ID --on mol-docs-review
```

The refinery's next patrol sees all four `*_approved` fields set and proceeds to `approval-review` and `merge-push`. Wait for the PR:

**Copy and paste**

```bash
watch -n 5 'gc bd show $BEAD_ID | grep -E "pr_url|pr_number"'
# Ctrl-C once metadata.pr_number is set.

cd $ASCII_ART_PATH
export PR=$(BD_JSON_ENVELOPE=1 gc bd show $BEAD_ID --json | jq -r '.data[0].metadata.pr_number')
gh pr view "$PR" --web
gh pr merge "$PR" --merge
```

### 6. Demonstrate vendor disagreement on a deliberately weak bead

Hand-craft a violation-rich implementation on `Implement o.md` so the three vendors honestly disagree with the diff. Stage a bad version of the file before the polecat runs:

**Copy and paste**

```bash
cd "$ASCII_ART_PATH"
export WEAK_BEAD=$(bd list --type=task --status=open --limit 0 | grep -E "Implement o\.md$" | awk '{print $2}')

git checkout -b weak/o
mkdir -p ascii && cat > ascii/o.md <<'BAD'
# o (deliberately weak)
   X X X
   X   X
   X   X
   X X X
BAD
git add ascii/o.md && git commit -m "implement o (deliberately weak)" && git push -u origin weak/o
```

Run the standard pipeline:

**Copy and paste**

```bash
cd $FACTORY_PATH
gc sling ascii-art/multi-vendor-rig.design-lead $WEAK_BEAD --on mol-design-spec
gc sling ascii-art/multi-vendor-rig.test-lead   $WEAK_BEAD --on mol-test-spec
gc sling ascii-art/multi-vendor-rig.doc-lead    $WEAK_BEAD --on mol-doc-spec
cd $ASCII_ART_PATH
git add docs/design docs/testing docs/outlines && git commit -m "docs(specs): pre-PM specs for $WEAK_BEAD" && git push origin main

cd $FACTORY_PATH
gc sling ascii-art/multi-vendor-rig.project-manager $WEAK_BEAD --on mol-bead-review
# Wait for PASS, polecat to publish branch.
watch -n 5 'gc bd show $WEAK_BEAD | grep -E "branch"'

# Sling all three vendor reviewers.
gc sling ascii-art/multi-vendor-rig.reviewer-codex  $WEAK_BEAD --on mol-vendor-codex-review
gc sling ascii-art/multi-vendor-rig.reviewer-claude $WEAK_BEAD --on mol-vendor-claude-review
gc sling ascii-art/multi-vendor-rig.reviewer-gemini $WEAK_BEAD --on mol-vendor-gemini-review
```

What you should see:

- All three vendors honestly score the diff. Probably 2-3 of them reject (the file isn't really an "o" — it's a square — and the ADR rules will catch that).
- After all three stamp, sling the synthesizer:

  **Copy and paste**

  ```bash
  gc sling ascii-art/multi-vendor-rig.synthesizer $WEAK_BEAD --on mol-synthesize-reviews
  ```

  Expected: `adr_approved=false`, `synthesizer_summary` names which vendors rejected and why.
- The refinery's `verify-reviewers` reads `adr_approved=false`, increments `review_loops`, and bounces the bead to the polecat pool with the synthesizer's summary as the rejection reason.
- The polecat picks up the bead, reads `review_feedback`, and re-implements. The cycle continues up to 2 rejection rounds before the refinery's H2 cap fires.

Inspect the bead's notes after the loop runs:

**Copy and paste**

```bash
gc bd show $WEAK_BEAD
# NOTES will record the three vendor verdicts per cycle plus the
# synthesizer's summary.
```

### 7. Reflect — Tutorial complete

**What you've built.** A software factory. A city, a rig, a sandbox repo, a working pool of agents. Beads enter through a `project-manager` that runs conformity checks; three Leads (design, test, doc) draft per-bead specs before any polecat is allowed to start. The polecat publishes a branch; the refinery dispatches four parallel domain reviewers (ADR, design, testing, docs); the ADR lane itself fans out to three vendor-pinned reviewers plus a synthesizer. The refinery aggregates all four lanes, runs its own mechanical sanity checks, and publishes a PR. Branch protection requires a CODEOWNER human approval before anything ships. Every concern has an owner; every decision has a gate; every gate has a durable trail on the bead.

**What's next.** This is where the tutorial ends. From here, the direction is yours.

- **Scale up.** Raise pool concurrency, add rigs, run multiple repos under one city.
- **Replace the deliverable.** ASCII letter files are an exercise. Swap them for the real work your team does — services, libraries, ML pipelines, infrastructure modules. The agent shape is stable; the rig content is yours.
- **Auto-dispatch the multi-vendor fan-out.** Manual slinging of three vendor reviewers per bead is not how a hardened factory runs in production. Patch the H2 refinery's `verify-reviewers` step to auto-dispatch the three vendor formulas (and the synthesizer once they're done) the same way it dispatches the other three lanes. The pattern is in `mol-refinery-domain-patrol` — extend it.
- **Fan out the other three lanes.** What works for ADR works for design, testing, and docs. Three vendors per lane plus a synthesizer per lane gives you 12 reviewer wisps and 4 synthesizers per bead — costly, but the strongest review infrastructure short of a human review.
- **Contribute back.** The packs in this tutorial are deliberately small. If your variant is useful, contribute it back to the Gas City community packs.

You've got the shape now.

## Verification

Confirm the four new formulas loaded:

**Copy and paste**

```bash
gc formula list \
  | grep -E "mol-vendor-(codex|claude|gemini)-review|mol-synthesize-reviews"
```

**Expected output**

```text
# Four rows: mol-vendor-codex-review, mol-vendor-claude-review,
# mol-vendor-gemini-review, mol-synthesize-reviews.
```

After running the three vendors and the synthesizer on `$BEAD_ID`, confirm the bead carries three vendor verdicts plus a synthesizer summary plus `adr_approved`:

**Copy and paste**

```bash
gc bd show $BEAD_ID | grep -E "vendor_|synthesizer_summary|adr_approved"
```

**Expected output**

```text
# Three vendor_*_approved rows, optionally vendor_*_feedback,
# synthesizer_summary, adr_approved.
```

Confirm the letter landed on `origin/main`:

**Copy and paste**

```bash
git fetch origin && git pull
ls ascii/n.md
```

## Troubleshooting

- **Provider X not installed.** The matching vendor reviewer cannot spawn. Either install the provider, or run the H4 flow with the remaining vendors. With two vendors, both must approve for the synthesizer to stamp `adr_approved=true`. With one, the synthesizer always says `false` (1 vote is not majority by design — adjust the synthesizer prompt if you want a different policy for solo-vendor mode).
- **Synthesizer escalates with `<2 votes`.** The vendors posted `--comment` instead of approve / request-changes. (This is the GitHub self-author footgun from page 03 in disguise — the vendors are reviewing a feature branch, not a PR, so it shouldn't fire here. If it does, your vendor reviewer prompt is leaking PR-review semantics into a branch-review flow.)
- **Vendor stamps a value that isn't `true` or `false`.** The shared prompt explicitly says to write `true` or `false`. If a vendor wrote `yes` / `no` / `approved` / a free-form sentence, the synthesizer's count goes wrong. Edit the vendor reviewer prompt to be more emphatic about the literal stamp value.
- **Synthesizer stamps `adr_approved=true` despite obvious violations.** Read `synthesizer_summary` — the synthesizer followed majority rule on what the three vendors wrote. If two vendors approved a bad diff, the synthesizer is doing its job, not yours; the issue is upstream (vendor prompt drift, training-data overlap between two of the three vendors). Lower the approval threshold (require unanimity instead of majority), or add a fourth vendor.
- **Cost spikes.** Three vendors per bead adds up. Reserve the full trio for risky changes; for routine work, fall back to the H3 single-vendor principles loop or the H2 single-vendor `adr-reviewer`.
- **Refinery loops three or more times despite the cap.** The H2 cap (`review_loops >= 2`) bounds bounces; check `metadata.review_loops` and confirm the refinery is running `mol-refinery-domain-patrol`.
- **`<coordinator>` mail bounces.** Substitute your operator handle (e.g., `mayor`).

## What's next

Return to the [tutorial index](../README.md). The Hardening track is complete. Beyond this, the direction is yours.

« [previous: L-3 Hardening — Track A, scoring](./03-architecture-best-practices-loop.md) | [next: L-4 Self-improvement Loop](./05-self-improvement-loop.md) »
