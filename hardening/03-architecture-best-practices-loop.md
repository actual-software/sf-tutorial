# Architecture best-practices loop

« [previous: L-2 Retargeting the Rig](./02-specialize-reviewers-per-domain.md) | [next: L-3 Hardening — Track B, multi-vendor](./04-strengthen-review-system.md) »

**Lab L-3 · Hardening · Thursday 10:45–12:00 · 75 minutes · your own project**

## Block L-3: Hardening

This page opens L-3, and the block is a choice between two tracks: this page is Track A, and [`04`](./04-strengthen-review-system.md) is Track B. Everything under this heading frames the choice. Track A's walkthrough starts at [Objective](#objective).

### What the block is for

Take one review mechanism past "an agent looked at it" and into something you could show an auditor or a skeptical colleague. You pick which of two directions that means.

### Before the block starts

- [L-2](./02-specialize-reviewers-per-domain.md) complete, or `ascii-art` at the end of W-5 if you are running this on the shared example.
- For Track B only: `codex`, `claude` and `gemini` all installed and authenticated on your machine. Check this *before* the block starts, not at 11:00.

### Choose one: scoring or multi-vendor

This is the longest lab of the two days and it is the meatiest choice. The two tracks solve different problems and you have time for one.

| | Track A · Scoring | Track B · Multi-vendor |
| --- | --- | --- |
| Source page | This page | [`04`](./04-strengthen-review-system.md) |
| The problem it solves | "The reviewer said it was fine" is not evidence | One model's blind spot is the whole factory's blind spot |
| What you build | Per-principle scores against a 23-principle schema, with an append-only YAML audit trail per iteration | Three vendor-pinned reviewers in parallel, fused by a synthesizer with a majority rule |
| Pick it if | You need to defend a decision later, or your organisation will ask "on what basis" | You have seen a model be confidently wrong, or you want a cheaper model doing the first pass |
| Extra setup | None beyond the pack | Three CLI providers installed and authenticated |
| Watch out for | The schema is the work. A vague principle scores meaninglessly. | Cost and latency both roughly triple |

Track B also answers a question that comes up in almost every factory conversation: whether a cheaper model can carry part of the review load. Running three vendors side by side on the same bead is the fastest way to find out on your own code, rather than on a benchmark.

If you genuinely cannot choose, take Track A. The audit trail is useful to more people more often, and Track B is the easier of the two to work through alone afterwards.

### How the lab runs

Twenty-five minutes of demo covering both tracks, then fifty minutes in which you build one. Say which track you picked when the instructor comes round, so pairing lands sensibly.

**Track A, per-principle scoring with an audit trail.** Work this page. Its shape: install the `principles-loop-rig` pack, author and commit a principles schema, run a clean bead through the loop and watch it pass on iteration 1, then run a deliberately weak bead and watch the loop iterate.

The part that transfers to your project is step 2, authoring the schema. `ascii-art`'s schema has 23 principles because its domain is small and closed. Yours will not be. Write five principles you would actually defend in a design review rather than twenty-three you copied, and make each one specific enough that two reviewers would score it the same way. "Code should be maintainable" scores randomly. "Every public function that can fail returns an error rather than raising" scores consistently.

The audit trail is append-only YAML, one entry per iteration. Open it after your second run. It is the artifact that answers "on what basis", and it is the reason this track is worth 50 minutes.

**Track B, multi-vendor review with a synthesizer.** Work [`04-strengthen-review-system.md`](./04-strengthen-review-system.md). Its shape: install the `multi-vendor-rig` pack, verify three CLI providers are authenticated, carry a clean bead through the standard pipeline, then review it with three vendor-pinned reviewers in parallel and fuse the results with a synthesizer. Then repeat with a deliberately weak bead to exercise disagreement, the majority rule, and the refinery's bounce path.

Step 6 is the one that matters there. Vendor agreement on a clean bead tells you very little; the interesting signal is where they disagree and what the synthesizer does about it. Read the three raw verdicts before you read the synthesized one, and decide for yourself which reviewer was right. If the majority was wrong, that is a finding about your synthesizer's rule rather than about the models.

Check your provider auth first. `04` step 1 verifies all three, and an unauthenticated provider fails late and confusingly.

### What you leave with

Either an append-only audit trail with per-principle scores for at least two runs, or three vendor verdicts on one bead plus the synthesizer's fused result and a note on where they disagreed.

Both tracks produce a file you can show someone. That is the point of the block.

Check the block landed. Track A:

```bash
ls -la <your-rig>/docs/reviews/
tail -40 <your-rig>/docs/reviews/*.yaml
```

Track B:

```bash
gc session list
bd show <bead-id> --json | jq '.[0].metadata | to_entries | map(select(.key | startswith("vendor")))'
```

### If you fall behind in this block

Both tracks run fine on `ascii-art` if your own rig is not cooperating:

```bash
cd path/to/sf-tutorial/bootstrap
./bootstrap.sh 05.1-bead-gate-checks
```

Then work your chosen track as written. Retarget afterwards; the mechanics are identical and the setup cost is what you are avoiding.

### Ceiling

Run the other track. That is genuinely the best use of extra time here, and the two compose: per-principle scoring gives the multi-vendor synthesizer something concrete to disagree about, instead of three prose opinions it has to reconcile by vibe.

If you would rather go deeper than wider, take the track you chose and make it fail on purpose. Write a principle no reviewer can score, or pin two of the three vendors to the same model and see whether your majority rule notices. A gate you have not seen fail is a gate you do not yet understand.

### Block troubleshooting

- **The scoring loop never converges.** At least one principle is unscoreable as written. Read the lowest-scoring entry in the audit trail; the reviewer's own comment usually names the ambiguity.
- **One vendor lane hangs.** That provider is not authenticated, or its CLI is not on `PATH` for the agent's environment. Run its `--version` command yourself in a fresh shell.
- **The synthesizer picks an answer you disagree with.** That is a real result, not a bug. Its rule is in `artifacts/packs/multi-vendor-rig/agents/synthesizer/prompt.template.md`, and editing it is a legitimate use of the remaining time.

### Where the block goes next

You have made the factory's reviews stronger. [L-4 Self-improvement Loop](./05-self-improvement-loop.md) points the factory at its own configuration.

---

The rest of this page is Track A's walkthrough.

## Contents

- [Block L-3: Hardening](#block-l-3-hardening)
- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context](#context)
- [Walkthrough](#walkthrough)
  - [1. Install the principles-loop-rig pack into factory1](#1-install-the-principles-loop-rig-pack-into-factory1)
  - [2. Author and commit the principles schema doc](#2-author-and-commit-the-principles-schema-doc)
  - [3. Sling a clean bead through the standard pipeline](#3-sling-a-clean-bead-through-the-standard-pipeline)
  - [4. Watch the principles loop run (clean bead → PASS in iteration 1)](#4-watch-the-principles-loop-run-clean-bead--pass-in-iteration-1)
  - [5. Sling the loop on a deliberately weak bead](#5-sling-the-loop-on-a-deliberately-weak-bead)
  - [6. Reflect](#6-reflect)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

By the end of this exercise you will have installed the `principles-loop-rig` pack, run the ADR reviewer's per-principle scoring loop against both a clean bead and a deliberately weak bead, and produced an append-only YAML audit trail that records 23-principle scores per iteration.

## Prereqs

- Hardening 2 complete: `domain-reviewers-rig` is installed, four
  reviewer agents (`adr-reviewer`, `design-reviewer`,
  `testing-reviewer`, `docs-reviewer`) are registered, and the
  refinery is using `mol-refinery-domain-patrol`.
- `python3` available; `PyYAML` installed
  (`python3 -m pip install pyyaml`).
- You're inside the rig directory. If a fresh shell, re-export
  `$FACTORY_PATH`, `$ASCII_ART_PATH`, `$TUTORIAL_PATH`, and
  `$ARTIFACTS_PATH` per
  [00.3](../progression/00.3-setup-foundation.md), then
  `cd "$ASCII_ART_PATH"`.
- `gh` is authenticated; `jq` is installed.
- Letters consumed so far: a–k. The next two open task beads are
  `Implement l.md` (clean sanity check) and `Implement m.md` (the
  weak-bead demo).

## Context

Branching/Merging strategy is unchanged from page 04. What changes
here is the *depth* of the ADR-lane review introduced in Hardening
2. The single binary "ADR approved / rejected" verdict is replaced
with a per-principle scoring pass against **23 canonical
architecture principles**, each scored 0-5, with an **append-only
YAML audit trail** per bead. The loop self-pours up to 3 iterations
until the aggregate score clears the target threshold.

Agent workflow with the principles loop in place:

1. The **operator** runs the H1 Leads, project-manager, and polecat
   as before. The polecat publishes a branch and the bead carries
   the four-lane verdict fields (unset on a fresh bead).
1. The **refinery's** `verify-reviewers` step (H2) sees
   `adr_approved` is unset and slings the adr-reviewer with the new
   formula `mol-principles-review` (instead of the H2
   `mol-adr-review`). The other three lanes — design, testing,
   docs — continue to use their H2 formulas unchanged.
1. The **adr-reviewer** runs `mol-principles-review`:
   - Reads the diff and the ADR corpus.
   - Scores the diff against each of the 23 canonical principles
     (DRY, SoC, SRP, KISS, YAGNI, ...). One row per principle is
     appended to `docs/reviews/principles.<bead-id>.yaml`. Detailed
     findings per principle land in
     `docs/reviews/principles/<bead-id>.<slug>.md`.
   - Runs the aggregator (`checks/aggregate-score.sh`) on the YAML.
   - Branches on the aggregator's exit code:
     - **PASS (rc=0)**: aggregate ≥ target and every principle's
       latest score ≥ floor. Stamps `adr_approved=true` and
       `principles_review_passed=true`. Reassigns to refinery.
     - **CONTINUE (rc=1)**: aggregate below target or some floor
       below min. Self-pours the formula with `iteration += 1`. Cap
       at 3 iterations; the 3rd CONTINUE escalates.
     - **ESCALATE (rc=2)**: malformed YAML, duplicate timestamps,
       or a principle name not in the canonical 23. Mails operator,
       stamps `adr_approved=false`. Reassigns to refinery.
1. The **refinery** sees `adr_approved` set (along with the other
   three lanes) and aggregates as in H2. The principles loop's
   verdict surfaces through the same lane the H2 ADR reviewer used,
   so no refinery prompt change is required.
1. The **merger** (human, plus branch protection from page 03)
   reads the YAML audit trail (now part of the bead's durable
   record) plus the four-lane verdicts and clicks **Merge**.

The reviewers do **not** push code, count cycles for *all* lanes,
or close the bead. The principles loop owns its own iteration
counter (`iteration` formula var) — separate from the refinery's
cross-lane `review_loops` counter from H2.

In this exercise you install the **principles-loop-rig** pack into the `ascii-art` rig
(removing `domain-reviewers-rig` from the rig's direct imports — the
new pack imports it transitively). Drop the principles schema doc
into the rig. Sling the next letter through the standard pipeline
(Leads → project-manager → polecat → refinery), then watch the
adr-reviewer fan out 23 scoring writes into the YAML audit trail.
The aggregator decides PASS or CONTINUE; on CONTINUE the formula
self-pours with the next iteration. Then deliberately weaken a
later bead and watch the loop iterate 2-3 times until aggregate
converges (or the cap trips and operator gets mailed).

The next page (Hardening 4) adds review **breadth** instead of
depth: vendor-diverse reviewers (Codex / Claude / Gemini) plus a
synthesizer that fuses three independent verdicts into one.

## Walkthrough

### 1. Install the principles-loop-rig pack into factory1

The page H2 setup gave the rig a four-lane review breadth — but
the ADR lane was still binary. Real architectural review is multi-
dimensional: a diff might be DRY-perfect but coupling-heavy, or
test-coverage-strong but observability-weak. The 23 canonical Gas
City principles capture those dimensions; per-principle scoring
makes "ADR review" a continuous quality measure rather than a
yes/no gate.

This ships as a single rig-scoped pack, **`principles-loop-rig`**,
that adds depth along the ADR lane:

- A new formula `mol-principles-review` that the adr-reviewer
  pours instead of `mol-adr-review`. Scores the diff against 23
  principles, appends to a per-bead YAML, runs the aggregator,
  branches on PASS / CONTINUE / ESCALATE.
- A check script `checks/aggregate-score.sh` — the source of truth
  for PASS / CONTINUE / ESCALATE. Reads the YAML, computes
  latest-row-wins aggregate, exits 0 / 1 / 2.
- A schema doc `docs/reviews/principles-schema.md` (lives in the
  rig, not the pack — it documents the audit-trail format).

The H2 refinery's `verify-reviewers` step is **unchanged**. It
slings the adr-reviewer with `--on mol-adr-review` by default; this
hardening replaces `mol-adr-review` with `mol-principles-review` at
the dispatch layer (either by user-facing convention as taught in
this lesson, or by patching the refinery prompt — H4 does this).
For now, when the operator slings the adr-reviewer manually, they
sling with `--on mol-principles-review`. Auto-dispatch from the
refinery still uses `mol-adr-review` (the binary check); this
lesson focuses on the manual deeper review that runs in addition.

The loop cap is **3 iterations** (separate from H2's 2-rejection
cross-lane cap).

Inspect the pack:

**Copy and paste**

```bash
ls "$ARTIFACTS_PATH/packs/principles-loop-rig/"
cat "$ARTIFACTS_PATH/packs/principles-loop-rig/pack.toml"
cat "$ARTIFACTS_PATH/packs/principles-loop-rig/formulas/mol-principles-review.formula.toml"
cat "$ARTIFACTS_PATH/packs/principles-loop-rig/checks/aggregate-score.sh"
```

What to notice:

- **Canonical 23.** The formula's principle list and the
  aggregator's `CANONICAL` array are byte-identical. Any deviation
  (e.g., `Separation of Concerns (SoC)` with parenthetical alias)
  trips the aggregator's "principle not in canonical 23" check and
  escalates.
- **Latest-row-wins.** The YAML is append-only; the aggregator
  groups by principle name, keeps the highest-timestamp row, sums
  scores, divides by `5 * 23`. Missing principles count as 0 — so
  partial coverage cannot pass.
- **Self-pour pattern.** On CONTINUE, the formula `gc sling`s
  itself with `--var iteration=$NEXT`. Cap at 3.

Copy the pack into the city's pack directory:

**Copy and paste**

```bash
cp -r "$ARTIFACTS_PATH/packs/principles-loop-rig" \
      "$FACTORY_PATH/.gc/system/packs/principles-loop-rig"
```

Register the new import at rig scope:

**Copy and paste**

```bash
cd "$FACTORY_PATH"

gc import add --rig ascii-art .gc/system/packs/principles-loop-rig
gc import remove --rig ascii-art domain-reviewers-rig
```

The rig should now import `principles-loop-rig` and no longer import `domain-reviewers-rig`.

**Copy and paste**

```bash
gc import list --rig ascii-art
```

**Expected output**

```text
TBD: capture actual terminal output during smoke test
```

Restart and confirm the new formula loaded — one row for `mol-principles-review`.

**Copy and paste**

```bash
gc restart

gc formula list | grep mol-principles-review
```

**Expected output**

```text
TBD: capture actual terminal output during smoke test
```

Check the aggregator script exists, and run it bare to confirm it prints a usage message and exits 2.

**Copy and paste**

```bash
ls "$FACTORY_PATH/.gc/system/packs/principles-loop-rig/checks/aggregate-score.sh"
bash "$FACTORY_PATH/.gc/system/packs/principles-loop-rig/checks/aggregate-score.sh"
```

**Expected output**

```text
TBD: capture actual terminal output during smoke test
```

Confirm PyYAML is installed (a version string prints). If you get `ModuleNotFoundError`, run `python3 -m pip install pyyaml`.

**Copy and paste**

```bash
python3 -c "import yaml; print(yaml.__version__)"
```

**Expected output**

```text
TBD: capture actual terminal output during smoke test
```

### 2. Author and commit the principles schema doc

The schema doc is the human-readable reference for the YAML
format. It lives in the rig (not the pack), committed alongside
the audit trail. Drop the version from the pack into
`docs/reviews/principles-schema.md` if your pack ships one; if
not, write a short one inline:

**Copy and paste**

```bash
cd "$ASCII_ART_PATH"
mkdir -p docs/reviews docs/reviews/principles
cat > docs/reviews/principles-schema.md <<'EOF'
# Principles audit trail schema

`docs/reviews/principles.<bead-id>.yaml` is the per-bead
append-only audit trail produced by `mol-principles-review`. Each
row:

```yaml
- principle: <canonical name from the 23>
  iteration: <integer, starts at 1>
  score: <0-5>
  timestamp: <ISO 8601 UTC>
  reviewer: <agent name>
  notes_file: docs/reviews/principles/<bead-id>.<slug>.md
```

Aggregator: `(sum of latest-per-principle scores) / (5 * 23)`. Min
floor: every principle's latest row must score >= 3. Missing
principles count as 0.
EOF

git add docs/reviews/principles-schema.md
git commit -m "docs(reviews): add principles audit-trail schema"
git push origin main
```

### 3. Sling a clean bead through the standard pipeline

Same recipe as Hardening 1 and 2, up to and including the polecat
publishing a branch:

**Copy and paste**

```bash
cd "$ASCII_ART_PATH"
export BEAD_ID=$(bd list --type=task --status=open --limit 0 | grep -E "Implement l\.md$" | awk '{print $2}')

cd $FACTORY_PATH
gc sling ascii-art/principles-loop-rig.design-lead $BEAD_ID --on mol-design-spec
gc sling ascii-art/principles-loop-rig.test-lead   $BEAD_ID --on mol-test-spec
gc sling ascii-art/principles-loop-rig.doc-lead    $BEAD_ID --on mol-doc-spec
cd $ASCII_ART_PATH
git add docs/design docs/testing docs/outlines && git commit -m "docs(specs): pre-PM specs for $BEAD_ID" && git push origin main

cd $FACTORY_PATH
gc sling ascii-art/principles-loop-rig.project-manager $BEAD_ID --on mol-bead-review
# Wait for PASS, polecat picks up, refinery picks up.
watch -n 5 'gc bd show $BEAD_ID | grep -E "_approved|branch|review"'
```

When the bead is back at the refinery and `adr_approved` is unset,
manually sling the adr-reviewer with the principles formula
**instead of** waiting for the refinery's auto-dispatch (which would
sling `mol-adr-review`):

**Copy and paste**

```bash
cd $FACTORY_PATH
gc sling ascii-art/principles-loop-rig.adr-reviewer $BEAD_ID --on mol-principles-review
```

### 4. Watch the principles loop run (clean bead → PASS in iteration 1)

The adr-reviewer scores 23 principles, appends to the YAML, runs
the aggregator. On a clean diff, aggregate clears 0.9 in iteration
1.

**Copy and paste**

```bash
gc session list
gc session attach <adr-reviewer-session>
```

When the session ends, inspect the YAML and the per-principle
findings:

**Copy and paste**

```bash
cd $ASCII_ART_PATH
cat docs/reviews/principles.$BEAD_ID.yaml | head -50
ls docs/reviews/principles/$BEAD_ID.*.md
```

Run the aggregator by hand to see the JSON line it emitted:

You should see `rc=0` and a JSON line on stdout with `aggregate>=0.9`.

**Copy and paste**

```bash
$FACTORY_PATH/.gc/system/packs/principles-loop-rig/checks/aggregate-score.sh \
  docs/reviews/principles.$BEAD_ID.yaml --target=0.9 --min-per-principle=3
echo "rc=$?"
```

**Expected output**

```text
TBD: capture actual terminal output during smoke test
```

Confirm `adr_approved=true` and `principles_review_passed=true` are
stamped on the bead:

**Copy and paste**

```bash
gc bd show $BEAD_ID | grep -E "adr_approved|principles_review_passed"
```

Run the other three lane reviewers (manually, or wait for the
refinery's auto-dispatch — both work):

**Copy and paste**

```bash
cd $FACTORY_PATH
gc sling ascii-art/principles-loop-rig.design-reviewer  $BEAD_ID --on mol-design-review
gc sling ascii-art/principles-loop-rig.testing-reviewer $BEAD_ID --on mol-testing-review
gc sling ascii-art/principles-loop-rig.docs-reviewer    $BEAD_ID --on mol-docs-review
```

Wait for the refinery to aggregate and publish the PR:

**Copy and paste**

```bash
watch -n 5 'gc bd show $BEAD_ID'
# Ctrl-C once metadata.pr_number is set.

cd $ASCII_ART_PATH
export PR=$(BD_JSON_ENVELOPE=1 gc bd show $BEAD_ID --json | jq -r '.data[0].metadata.pr_number')
gh pr view "$PR" --web
gh pr merge "$PR" --merge
```

### 5. Sling the loop on a deliberately weak bead

The demonstration. Hand-craft a violation-rich implementation on
`Implement m.md` so the loop has something to iterate against.
Stage a bad version of the file before the polecat runs:

**Copy and paste**

```bash
cd $ASCII_ART_PATH
export WEAK_BEAD=$(bd list --type=task --status=open --limit 0 | grep -E "Implement m\.md$" | awk '{print $2}')

git checkout -b weak/m
mkdir -p ascii && cat > ascii/m.md <<'BAD'
# m (deliberately weak)
   M   M
   MM MM
   M M M
   M   M
BAD
git add ascii/m.md && git commit -m "implement m (deliberately weak)" && git push -u origin weak/m
```

Run the standard pipeline so the polecat opens the PR around the
bad code:

**Copy and paste**

```bash
cd $FACTORY_PATH
gc sling ascii-art/principles-loop-rig.design-lead $WEAK_BEAD --on mol-design-spec
gc sling ascii-art/principles-loop-rig.test-lead   $WEAK_BEAD --on mol-test-spec
gc sling ascii-art/principles-loop-rig.doc-lead    $WEAK_BEAD --on mol-doc-spec
cd $ASCII_ART_PATH
git add docs/design docs/testing docs/outlines && git commit -m "docs(specs): pre-PM specs for $WEAK_BEAD" && git push origin main

cd $FACTORY_PATH
gc sling ascii-art/principles-loop-rig.project-manager $WEAK_BEAD --on mol-bead-review

# Wait for the polecat to publish the (weak) branch...
watch -n 5 'gc bd show $WEAK_BEAD | grep -E "branch|pr_url"'

# ... then sling the principles loop.
gc sling ascii-art/principles-loop-rig.adr-reviewer $WEAK_BEAD --on mol-principles-review
```

What you should see across iterations:

- **Iteration 1**: 23 rows appended; aggregate well below 0.9
  (DRY, KISS, Don't Swallow Errors, TDD likely 0-2). Aggregator
  returns 1 (CONTINUE); the formula self-slings with
  `iteration=2`.
- **Iteration 2**: a polecat pass against the lowest-scoring
  principles fixes the worst offenders; the 23 reviewers re-score;
  aggregate climbs.
- **Iteration 3**: same loop. If aggregate now clears 0.9 with no
  principle below 3, stamps PASS. Otherwise the cap trips and
  operator gets mailed.

Watch the YAML grow:

**Copy and paste**

```bash
watch -n 5 'wc -l docs/reviews/principles.$WEAK_BEAD.yaml'
```

**Expected output**

```text
~140 lines after iteration 1, ~280 after 2, ~420 after 3.
```

Run the aggregator between iterations:

**Copy and paste**

```bash
cd $ASCII_ART_PATH
$FACTORY_PATH/.gc/system/packs/principles-loop-rig/checks/aggregate-score.sh \
  docs/reviews/principles.$WEAK_BEAD.yaml --target=0.9 --min-per-principle=3
# Iteration 1: rc=1, JSON shows aggregate ~0.5, lowest 3 principles named.
# Iteration 2: rc=1, aggregate ~0.7, lowest principles changing.
# Iteration 3: rc=0 (PASS) or rc=1 (cap will trip on next CONTINUE).
```

### 6. Reflect

That worked. The ADR lane is no longer binary — the rig now
carries a 23-dimensional record per bead of how the implementation
scored across the canonical principles, with a per-iteration audit
trail you can review in PR comments or annual architecture
retrospectives. The aggregator's threshold (0.9 aggregate, 3-floor
per principle) is a knob: tighten it for hardened repos, loosen it
for greenfield prototypes.

What's still missing:

- **One vendor.** Every reviewer (and every principle scorer) runs
  against the same model. A second-opinion review from an
  independent model would catch principle-scoring blind spots.
  **Hardening 4 — Strengthen the review system** stands up
  vendor-diverse reviewers (Codex / Claude / Gemini) with a
  synthesizer.
- **Principles list is hard-coded.** The 23 canonical names are
  baked into both the formula and the aggregator. Different
  domains (e.g., a UI library, an ML pipeline) might want a
  different list. Forking the pack and editing the canonical
  arrays is the path; doing it cleanly via pack composition is a
  hardening-of-hardening.

## Verification

Pack is installed and the formula is loaded.

**Copy and paste**

```bash
gc formula list | grep mol-principles-review
ls "$FACTORY_PATH/.gc/system/packs/principles-loop-rig/checks/aggregate-score.sh"
python3 -c "import yaml" && echo "PyYAML ok"
```

After slinging on a clean bead, 23 rows in the YAML and PASS.

**Copy and paste**

```bash
wc -l docs/reviews/principles.$BEAD_ID.yaml
$FACTORY_PATH/.gc/system/packs/principles-loop-rig/checks/aggregate-score.sh \
  docs/reviews/principles.$BEAD_ID.yaml
echo "rc=$?"
```

**Expected output**

```text
~140 lines (23 rows × 6 fields), rc=0.
```

After slinging on the weak bead, at least 2 iterations of rows; final outcome PASS or escalation mail.

**Copy and paste**

```bash
wc -l docs/reviews/principles.$WEAK_BEAD.yaml
gc bd show $WEAK_BEAD | grep -E "principles_review_passed|adr_approved"
```

Per-principle findings exist.

**Copy and paste**

```bash
ls docs/reviews/principles/$BEAD_ID.*.md | head -5
```

## Troubleshooting

- **`python3` says `No module named yaml`.**
  `python3 -m pip install pyyaml`. The aggregator escalates with
  `PyYAML missing` if it cannot import.
- **Aggregator exits 2 with `principle not in canonical 23`.** A
  reviewer wrote a name that doesn't match — most often a
  parenthetical alias like `Separation of Concerns (SoC)`. Edit
  the offending YAML row to the canonical string and update the
  reviewer's prompt to stop emitting the alias.
- **Aggregator exits 2 with `duplicate row for principle=...`.**
  Two reviewer wisps appended at the exact same timestamp. Delete
  one duplicate; if this becomes common, add a small jitter to the
  timestamp generation in the formula.
- **Loop runs once and stops.** The CONTINUE branch must `gc sling`
  the formula again with `iteration=$NEXT`; if that sling silently
  fails the loop ends without escalation.
- **Loop hits cap at iteration 3 with aggregate stuck at 0.85.**
  Inspect the lowest-scoring principle in the JSON output. The
  implementation may genuinely violate it; either fix by hand or
  accept the escalation.
- **The principles loop's verdict didn't reach the refinery's
  cross-lane aggregator.** The refinery's `verify-reviewers` reads
  `adr_approved`, which the principles loop sets on PASS. Confirm
  `metadata.adr_approved` is set after the loop finishes, and that
  no other process unset it before the refinery's next patrol.
- **`<coordinator>` mail bounces.** Substitute your operator
  handle (e.g., `mayor`).

## What's next

Continue to [Strengthen the review system](./04-strengthen-review-system.md).
H4 adds review breadth on a different axis — vendor diversity. The
adr-reviewer (or any of the four domain reviewers) is replaced
with three vendor-pinned reviewers running in parallel, plus a
synthesizer agent that fuses three independent verdicts into one
recommendation.

« [previous: L-2 Retargeting the Rig](./02-specialize-reviewers-per-domain.md) | [next: L-3 Hardening — Track B, multi-vendor](./04-strengthen-review-system.md) »
