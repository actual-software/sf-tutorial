# Strengthen the Review System

## Contents

- [Objectives](#objectives)
- [Prereqs](#prereqs)
- [Context](#context)
- [Walkthrough](#walkthrough)
  - [1. Install the multi-vendor-rig pack into factory1](#1-install-the-multi-vendor-rig-pack-into-factory1)
  - [2. Sling a clean bead through the standard pipeline up to the polecat](#2-sling-a-clean-bead-through-the-standard-pipeline-up-to-the-polecat)
  - [3. Sling the three vendor reviewers, one at a time](#3-sling-the-three-vendor-reviewers-one-at-a-time)
  - [4. Sling the synthesizer](#4-sling-the-synthesizer)
  - [5. Watch the refinery pick the verdict up](#5-watch-the-refinery-pick-the-verdict-up)
  - [6. Demonstrate vendor disagreement on a deliberately weak bead](#6-demonstrate-vendor-disagreement-on-a-deliberately-weak-bead)
  - [7. Reflect — Tutorial complete](#7-reflect--tutorial-complete)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objectives

By the end of this exercise you will have:

- The `multi-vendor-rig` pack installed into the `ascii-art` rig, sitting directly on the base factory.
- Three CLI providers (`codex`, `claude`, `gemini`) verified as installed and authenticated on the host.
- A clean bead carried through the base factory's pipeline to the polecat, then reviewed by three vendor-pinned reviewers in parallel and fused by a `synthesizer`.
- A deliberately weak bead that exercises vendor disagreement, the synthesizer's majority rule, and the refinery's bounce path.

## Prereqs

- [W3](../progression/W3-run-your-factory.md) complete: the base factory installed on a rig, with the polecat, refinery and architect running.
- **Three CLI providers** installed and authenticated on the host running the pool: `codex`, `claude`, `gemini`. A cloud box ships all three, so there you only sign in to the ones you haven't used yet, in the box's terminal, as [the cloud box guide's step 5](../CLOUD_BOX_GUIDE.md#step-5-sign-in-to-your-coding-agent) shows: `codex login --device-auth` for Codex, and `gemini` with **Sign in with Google** for Gemini CLI. On your own machine each provider is installed separately; check the Gas City installation docs (or each provider's own docs) for current install instructions. Verify each is installed and signed in:

  **Copy and paste**

  ```bash
  codex --version
  claude --version
  gemini --version
  claude -p 'Reply with exactly: FACTORY_OK'
  codex login status
  gemini -p 'Reply with exactly: FACTORY_OK'
  ```

  Each prints a version, then Claude and Gemini each answer `FACTORY_OK` and Codex prints `Logged in using ChatGPT`.

  If any provider is missing, pick a different option: the synthesizer needs all three verdicts, and when one is missing it mails `mayor` and stops without a verdict (see Troubleshooting).

**This option needs no other option.** It installs on the base factory and adds three vendor-pinned reviewers and a synthesizer to the architecture lane. The synthesizer stamps `architect_approved`, which is the field the base factory's refinery patrol already gates on, so the fan-out is invisible from the refinery's side: it sees one architecture verdict, the same as before.
- `$SFI_PATH` set in your shell. [W2](../progression/W2-cloud-box-and-preflight.md) appends it to a shell rc, so it survives a new terminal. Every other path on this page is written out from it.
- You're inside the rig directory:

  **Copy and paste**

  ```bash
  cd "$SFI_PATH/ascii-art"
  ```
- `gh` is authenticated; `jq` and `watch` are installed (on a Mac, `brew install watch`).
- Letters consumed so far: a–m. The next two open task beads are `Implement n.md` (clean sanity check) and `Implement o.md` (the weak-bead demo).

## Context

Branching/merging strategy is unchanged from the base factory's architect. What changes here is the *vendor diversity* of the architecture review. The base factory's single architect runs against whichever model your harness pins. A single LLM is a single point of view; the cheapest way to harden a code review is to ask two more reviewers who were trained differently and synthesize their answers. This page does exactly that: three vendor-pinned reviewer agents (`reviewer-codex`, `reviewer-claude`, `reviewer-gemini`) run in parallel against the same diff and the same ADR corpus; a `synthesizer` agent reads all three verdicts and applies majority rule.

Agent workflow with the multi-vendor fan-out in place:

1. The **operator** slings the `polecat` as on the base factory. (Unchanged.)
1. The **polecat** publishes a feature branch and reassigns to the refinery. (Unchanged.)
1. The **operator** slings the three vendor reviewers at the bead in parallel:

   **Example**

   ```bash
   gc sling <rig>/multi-vendor-rig.reviewer-codex  <bead> --on mol-vendor-codex-review
   gc sling <rig>/multi-vendor-rig.reviewer-claude <bead> --on mol-vendor-claude-review
   gc sling <rig>/multi-vendor-rig.reviewer-gemini <bead> --on mol-vendor-gemini-review
   ```

   Each reviewer reads the same diff and the same ADR corpus, then stamps its own `vendor_<name>_approved` and (on rejection) `vendor_<name>_feedback` on the bead. The three sessions run in parallel — independence is the point; the rubric is identical across vendors, only the underlying model differs.
1. Once all three have stamped, the **operator** slings the synthesizer:

   **Example**

   ```bash
   gc sling <rig>/multi-vendor-rig.synthesizer <bead> --on mol-synthesize-reviews
   ```

   The synthesizer reads the three verdicts, applies majority rule (≥ 2 of 3 approve → `architect_approved=true`; otherwise `false`), and writes a one-paragraph `synthesizer_summary` distilling points of agreement and disagreement.
1. The **refinery** reads the `architect_approved` value the synthesizer wrote and proceeds as it always does. From the refinery's point of view this looks exactly like the single architect it already had; the fan-out is invisible to it.
1. The **merger** (human, plus branch protection) reads the verdict trail (with `synthesizer_summary` as the most useful single artifact for the ADR lane) and clicks **Merge**.

The vendor reviewers do **not** push code, share state with each other, or write to the `architect_approved` field themselves. The synthesizer does **not** read the diff; it only fuses what the three vendors wrote.

## Walkthrough

### 1. Install the multi-vendor-rig pack into factory1

The base factory's architecture review comes from a single vendor, so its blind spots are systematic rather than random. A second opinion from an independently trained model catches what one model consistently misses, and surfaces honest disagreement about what "compliant" means.

This ships as a single rig-scoped pack, **`multi-vendor-rig`**, that fans out the ADR lane:

- Three new rig-scoped reviewer agents (`reviewer-codex`, `reviewer-claude`, `reviewer-gemini`), each with its `provider` field pinned to a different CLI / API. The three agents share one prompt template — same rubric, same output contract; only the model differs.
- A new `synthesizer` agent that reads the three vendor verdicts and applies majority rule.
- Four new formulas: three vendor reviewer formulas (`mol-vendor-codex-review`, `mol-vendor-claude-review`, `mol-vendor-gemini-review`) and one synthesis formula (`mol-synthesize-reviews`).

The refinery's patrol is **unchanged**. The synthesizer writes `architect_approved` (true or false), the same field the base factory's architect writes, so the refinery cannot tell the difference. Left to itself, the patrol still routes each bead to the option's own architect as soon as `architect_approved` is unset, so the vendor review runs in addition to that default one, and the refinery acts on whichever verdict it reads first. Manual sling is the entry point in this lesson; auto-dispatch from the refinery, so the operator doesn't have to remember to sling four reviewers per bead, is left as a final exercise.

If you also installed the [domain reviewers](./02-specialize-reviewers-per-domain.md) option, its design, testing and docs lanes stay single-vendor. Fanning those out across vendors follows the same pattern shown here and is left as an exercise.

Inspect the pack:

**Copy and paste**

```bash
ls "$SFI_PATH/sf-tutorial/artifacts/packs/multi-vendor-rig/"
cat "$SFI_PATH/sf-tutorial/artifacts/packs/multi-vendor-rig/pack.toml"
ls "$SFI_PATH/sf-tutorial/artifacts/packs/multi-vendor-rig/agents/"
cat "$SFI_PATH/sf-tutorial/artifacts/packs/multi-vendor-rig/agents/reviewer-codex/agent.toml"
cat "$SFI_PATH/sf-tutorial/artifacts/packs/multi-vendor-rig/agents/shared/vendor-reviewer.template.md"
cat "$SFI_PATH/sf-tutorial/artifacts/packs/multi-vendor-rig/agents/synthesizer/prompt.template.md"
```

What to notice:

- **Three identical rubrics.** The shared `vendor-reviewer.template.md` is loaded by all three vendor agents. They differ only in `provider`. Identical rubric is deliberate: only the model varies, not the read.
- **Synthesizer is not a fourth reviewer.** Its prompt explicitly says "do NOT read the diff yourself." It reads only what the three vendors stamped.
- **Majority rule, no synthesis-by-LLM tricks.** The synthesizer counts `true` verdicts; ≥ 2 of 3 stamps `architect_approved=true`. The one-paragraph `synthesizer_summary` is for the operator's benefit; the gate is the count.

Register the new import at rig scope:

**Copy and paste**

```bash
cd "$SFI_PATH/factory1"

gc import add --rig ascii-art "$SFI_PATH/sf-tutorial/artifacts/packs/multi-vendor-rig"

# Nothing is removed. This option sits alongside the base factory,
# which keeps its orders, and brings its own copy of the base chain.

```

Before you reload, define the providers the reviewers run on. They need `codex`, `claude` and `gemini`, and the minimal template you chose at W3's `gc init` defined only the agent you picked there, so the city now rejects its whole config: on a city set up for Claude, `gc reload` lists `provider "codex": add [providers.codex] base = "builtin:codex"` and the same for `gemini`, and `gc agent list` and `gc formula list` fail too. `gc doctor --fix` appends the missing provider aliases to `city.toml`:

**Copy and paste**

```bash
cd "$SFI_PATH/factory1"
gc doctor --fix
grep -A1 '^\[providers\.' city.toml
```

**Expected output**

```text
doctor's report, then three provider stanzas, each a header and its base line:
[providers.claude] with base = "builtin:claude", written by gc init
[providers.codex] with base = "builtin:codex", added by doctor
[providers.gemini] with base = "builtin:gemini", added by doctor
```

On a city set up for Codex or Gemini, the stanza from `gc init` is that provider's, and doctor adds the other two. A stanza only names a provider: Codex and Gemini also have to be signed in on the box, as [Prereqs](#prereqs) describes.

The option arrives with its own copy of the base chain. It imports `architect-rig`, so once the city reloads, `gc agent list --rig ascii-art` shows `multi-vendor-rig.architect`, `multi-vendor-rig.polecat` and `multi-vendor-rig.refinery` beside the three `base-factory` ones, plus the option's `reviewer-codex`, `reviewer-claude`, `reviewer-gemini` and `synthesizer`. It also lists a `multi-vendor-rig.shared`, which is the directory holding the reviewers' shared prompt picked up as an agent; it never gets work. The reviewers and the synthesizer hand the bead back to the refinery in their own copy, which is why every sling on this page names `ascii-art/multi-vendor-rig.<agent>`. The short `gc sling --rig ascii-art polecat` form stops resolving, with `agent "polecat" not found in city.toml`.

The rig now imports `multi-vendor-rig` beside `base-factory`.

**Copy and paste**

```bash
gc import list --rig ascii-art
```

**Expected output**

```text
base-factory	file:///home/ubuntu/software-factory-intensive/sf-tutorial//artifacts/packs/base-factory	sha:<commit>	sha:<commit>
multi-vendor-rig	file:///home/ubuntu/software-factory-intensive/sf-tutorial//artifacts/packs/multi-vendor-rig	sha:<commit>	sha:<commit>
```

That is a cloud box's output, plus a row for any other option you have installed; on your own machine the paths start from your own `$SFI_PATH`. The `sha:` is the commit your clone is on, and the import stays pinned to it, so later edits to the pack's files in `sf-tutorial` never reach the factory.

Reload and confirm the new formulas loaded — four rows.

**Copy and paste**

```bash
cd "$SFI_PATH/factory1"
gc reload

cd "$SFI_PATH/ascii-art"
gc formula list \
  | grep -E "mol-vendor-(codex|claude|gemini)-review|mol-synthesize-reviews"
```

**Expected output**

```text
Config reloaded: <n> agents (+<m>), <r> rigs (rev …)
four rows, one each for mol-vendor-codex-review, mol-vendor-claude-review, mol-vendor-gemini-review and mol-synthesize-reviews
```

If the supervisor's own tick got there first, `gc reload` prints `No config changes detected.` instead, which means the option is already loaded. A `provider "codex"` line in its place means `gc doctor --fix` has not run yet.

### 2. Sling a clean bead through the standard pipeline up to the polecat

Same recipe as Hardening 1 / 2 / 3 up through the polecat publishing a branch.

**Copy and paste**

```bash
cd "$SFI_PATH/ascii-art"
export BEAD_ID=$(bd list --type=task --status=open --limit 0 | grep -E "Implement n\.md$" | awk '{print $2}')

cd "$SFI_PATH/factory1"
gc sling ascii-art/multi-vendor-rig.polecat $BEAD_ID --on mol-polecat-pr
# Wait for the polecat to publish a branch and hand back to the refinery:
# it stamps merge_strategy as it hands over (branch appears earlier, when it starts).
watch -n 5 'gc bd show $BEAD_ID | grep -E "branch|merge_strategy|pr_url|_approved"'
```

When the polecat has pushed a branch and the bead is back at the refinery with `architect_approved` unset, proceed to step 3 straight away, before the option's own architect gets its verdict in.

### 3. Sling the three vendor reviewers, one at a time

Each sling spawns a separate session against a different model. Let each reviewer stamp its verdict before you sling the next: each `--on` attaches a reviewer's formula to the bead, and `gc sling` closes a formula still attached from an earlier sling before it attaches the new one, so three slings back to back leave only the last reviewer with any work. The `wait_for` helper below polls the bead until a reviewer has stamped its field.

**Copy and paste**

```bash
cd "$SFI_PATH/factory1"
wait_for() { until (cd "$SFI_PATH/ascii-art" && bd show "$1" --json | jq -e --arg k "$2" ".[0].metadata // {} | has(\$k)" >/dev/null); do sleep 10; done; echo "$2 stamped on $1"; }

gc sling ascii-art/multi-vendor-rig.reviewer-codex  $BEAD_ID --on mol-vendor-codex-review
wait_for "$BEAD_ID" vendor_codex_approved
gc sling ascii-art/multi-vendor-rig.reviewer-claude $BEAD_ID --on mol-vendor-claude-review
wait_for "$BEAD_ID" vendor_claude_approved
gc sling ascii-art/multi-vendor-rig.reviewer-gemini $BEAD_ID --on mol-vendor-gemini-review
wait_for "$BEAD_ID" vendor_gemini_approved
```

Watch:

You should see one reviewer session at a time, each against its own model.

**Copy and paste**

```bash
gc session list
```

**Expected output**

```text
one row per live session, three of them the vendor reviewers, one per provider
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

You should see one `vendor_<name>_approved` field appear per vendor, plus a `vendor_<name>_feedback` from any vendor that rejects:

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
cd "$SFI_PATH/factory1"
gc sling ascii-art/multi-vendor-rig.synthesizer $BEAD_ID --on mol-synthesize-reviews
```

Watch:

**Copy and paste**

```bash
gc session list
gc session attach <synthesizer-session>
```

The synthesizer reads the three verdicts, computes the count, and stamps `architect_approved` plus `synthesizer_summary`:

**Copy and paste**

```bash
gc bd show $BEAD_ID | grep -E "architect_approved|synthesizer_summary"
```

Expected on a 2-of-3 approve case:

**Expected output**

```text
architect_approved:           true
synthesizer_summary:    Codex and Claude approve. Gemini rejected
                        citing ADR-0001 rule 3 (line width). Codex
                        and Claude explicitly read line width as
                        compliant; the rejecting reviewer cited the
                        same rule with a stricter interpretation.
                        Forwarding as approved per majority.
```

### 5. Watch the refinery pick the verdict up

The synthesizer has stamped `architect_approved`, which is the one
architecture verdict the base factory's refinery waits on. Its next
patrol proceeds to `approval-review` and `merge-push` with nothing
further to run.

If you also installed the [domain reviewers](./02-specialize-reviewers-per-domain.md) option, it adds no lanes to this bead: its reviewers hand each bead they review to that option's own refinery, so leave them off this one.

Wait for the PR:

**Copy and paste**

```bash
watch -n 5 'gc bd show $BEAD_ID | grep -E "pr_url|pr_number"'
# Ctrl-C once metadata.pr_number is set.

cd "$SFI_PATH/ascii-art"
export PR=$(BD_JSON_ENVELOPE=1 gc bd show $BEAD_ID --json | jq -r '.data[0].metadata.pr_number')
gh pr view "$PR" --json url -q .url   # open this link in your laptop's browser
gh pr merge "$PR" --merge
```

### 6. Demonstrate vendor disagreement on a deliberately weak bead

Hand-craft a violation-rich implementation on `Implement o.md` so the three vendors honestly disagree with the diff. Stage a bad version of the file before the polecat runs:

**Copy and paste**

```bash
cd "$SFI_PATH/ascii-art"
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

bd update "$WEAK_BEAD" --set-metadata branch=weak/o
git checkout main
```

The polecat reuses a branch only when the bead names it in `metadata.branch`, which is why the block stamps `weak/o` on the bead. `git checkout main` then frees the branch, because git lets only one checkout hold a branch and the polecat works in a checkout of its own.

Run the standard pipeline:

**Copy and paste**

```bash
cd "$SFI_PATH/factory1"
gc sling ascii-art/multi-vendor-rig.polecat $WEAK_BEAD --on mol-polecat-pr
# Wait for the polecat to publish the (weak) branch: merge_strategy appears as it hands over.
watch -n 5 'gc bd show $WEAK_BEAD | grep -E "branch|merge_strategy"'

# Sling the three vendor reviewers one at a time, as in step 3.
wait_for() { until (cd "$SFI_PATH/ascii-art" && bd show "$1" --json | jq -e --arg k "$2" ".[0].metadata // {} | has(\$k)" >/dev/null); do sleep 10; done; echo "$2 stamped on $1"; }
gc sling ascii-art/multi-vendor-rig.reviewer-codex  $WEAK_BEAD --on mol-vendor-codex-review
wait_for "$WEAK_BEAD" vendor_codex_approved
gc sling ascii-art/multi-vendor-rig.reviewer-claude $WEAK_BEAD --on mol-vendor-claude-review
wait_for "$WEAK_BEAD" vendor_claude_approved
gc sling ascii-art/multi-vendor-rig.reviewer-gemini $WEAK_BEAD --on mol-vendor-gemini-review
wait_for "$WEAK_BEAD" vendor_gemini_approved
```

What you should see:

- All three vendors honestly score the diff. Probably 2-3 of them reject (the file isn't really an "o" — it's a square — and the ADR rules will catch that).
- After all three stamp, sling the synthesizer:

  **Copy and paste**

  ```bash
  gc sling ascii-art/multi-vendor-rig.synthesizer $WEAK_BEAD --on mol-synthesize-reviews
  ```

  Expected: `architect_approved=false`, `synthesizer_summary` names which vendors rejected and why.
- The refinery's `verify-architect` reads `architect_approved=false`, increments `review_loops`, and bounces the bead to the polecat pool with the synthesizer's summary as the rejection reason.
- The polecat picks up the bead, reads `review_feedback`, and re-implements. The cycle continues up to 2 rejection rounds before the refinery's cap fires. Each later round goes to the option's own architect, because the refinery routes the reworked bead there once `architect_approved` is cleared; sling the three reviewers and the synthesizer again to give that round the vendor review too.

Inspect the bead's notes after the loop runs:

**Copy and paste**

```bash
gc bd show $WEAK_BEAD
# NOTES will record the three vendor verdicts per cycle plus the
# synthesizer's summary.
```

### 7. Reflect — Tutorial complete

**What you've built.** A software factory. A city, a rig, a sandbox repo, a working pool of agents. The polecat publishes a branch; three vendor-pinned reviewers read it independently against the same ADRs; a synthesizer fuses their verdicts into the one `architect_approved` the refinery gates on. The refinery runs its own mechanical sanity checks and publishes a PR. Every concern has an owner; every decision has a gate; every gate has a durable trail on the bead.

**What's next.** This is where the tutorial ends. From here, the direction is yours.

- **Scale up.** Raise pool concurrency, add rigs, run multiple repos under one city.
- **Replace the deliverable.** ASCII letter files are an exercise. Swap them for the real work your team does — services, libraries, ML pipelines, infrastructure modules. The agent shape is stable; the rig content is yours.
- **Auto-dispatch the multi-vendor fan-out.** Manual slinging of three vendor reviewers per bead is not how a hardened factory runs in production. Patch the refinery patrol to dispatch the three vendor formulas, and the synthesizer once they're done, the way it already dispatches the architect.
- **Fan out the other three lanes.** What works for ADR works for design, testing, and docs. Three vendors per lane plus a synthesizer per lane gives you 12 reviewer wisps and 4 synthesizers per bead — costly, but the strongest review infrastructure short of a human review.
- **Contribute back.** The packs in this tutorial are deliberately small. If your variant is useful, contribute it back to the Gas City community packs.

You've got the shape now.

## Verification

Confirm the four new formulas loaded:

**Copy and paste**

```bash
cd "$SFI_PATH/ascii-art"
gc formula list \
  | grep -E "mol-vendor-(codex|claude|gemini)-review|mol-synthesize-reviews"
```

**Expected output**

```text
# Four rows: mol-vendor-codex-review, mol-vendor-claude-review,
# mol-vendor-gemini-review, mol-synthesize-reviews.
```

After running the three vendors and the synthesizer on `$BEAD_ID`, confirm the bead carries three vendor verdicts plus a synthesizer summary plus `architect_approved`:

**Copy and paste**

```bash
gc bd show $BEAD_ID | grep -E "vendor_|synthesizer_summary|architect_approved"
```

**Expected output**

```text
# Three vendor_*_approved rows, optionally vendor_*_feedback,
# synthesizer_summary, architect_approved.
```

Confirm the letter landed on `origin/main`:

**Copy and paste**

```bash
cd "$SFI_PATH/ascii-art"
git fetch origin && git pull
ls ascii/n.md
```

## Troubleshooting

- **`gc reload` lists `provider "codex": add [providers.codex] base = "builtin:codex"`.** The city does not define a provider the reviewers need, so it rejects the whole config, and `gc agent list` and `gc formula list` fail too. Run `gc doctor --fix` in `factory1`, then `gc reload`, as [step 1](#1-install-the-multi-vendor-rig-pack-into-factory1) shows.
- **Provider X not installed.** The matching vendor reviewer cannot spawn, so its `vendor_<name>_approved` never appears, and the synthesizer stops at that gap (next item) instead of voting with the other two. Install and sign in to the provider, or pick another option.
- **Synthesizer escalates with `missing vendor verdict`.** At least one reviewer had not stamped `vendor_<name>_approved` when you slung the synthesizer, so it noted which, mailed `mayor` and stopped without touching `architect_approved`. Sling the missing reviewer, wait for its stamp, then sling the synthesizer again.
- **Vendor stamps a value that isn't `true` or `false`.** The shared prompt explicitly says to write `true` or `false`. If a vendor wrote `yes` / `no` / `approved` / a free-form sentence, the synthesizer's count goes wrong. Edit the vendor reviewer prompt to be more emphatic about the literal stamp value (**An edit to a prompt or formula changes nothing**, below, says where).
- **Synthesizer stamps `architect_approved=true` despite obvious violations.** Read `synthesizer_summary` — the synthesizer followed majority rule on what the three vendors wrote. If two vendors approved a bad diff, the synthesizer is doing its job, not yours; the issue is upstream (vendor prompt drift, training-data overlap between two of the three vendors). Lower the approval threshold (require unanimity instead of majority), or add a fourth vendor.
- **Cost spikes.** Three vendors per bead adds up. Reserve the full trio for risky changes; for routine work, fall back to the base factory's single architect, or to the [principles loop](./03-architecture-best-practices-loop.md) if you want depth from one vendor.
- **Refinery loops three or more times despite the cap.** The cap (`review_loops >= 2`) bounds bounces; check `metadata.review_loops` and confirm which patrol formula the refinery is running.
- **`<coordinator>` mail bounces.** Substitute your operator handle (e.g., `mayor`).
- **The pull request opened before the synthesizer ran.** The refinery routed the bead to the option's own architect while `architect_approved` was unset and acted on that verdict, which the bead's notes show as `architect: APPROVED`. The vendor verdicts and the synthesizer's summary still land on the bead, so read them there. The **Auto-dispatch the multi-vendor fan-out** exercise in step 7 is what closes that gap.
- **An edit to a prompt or formula changes nothing.** The import is pinned to the commit your clone was on when you added it, so the factory never reads later edits to the pack in `sf-tutorial`, committed or not. Edit a copy outside any git clone and import that copy in place of this one, as [the feature labs' build step](../progression/L3-L5-feature-labs.md#2-build-it) shows.

## What's next

This is one of six options, and they are a menu rather than a sequence. Every one installs on the base factory alone, so take them in whatever order solves a problem you actually have. The full list is in [the feature labs](../progression/L3-L5-feature-labs.md#the-six-options).

Pairs naturally with the [architecture best-practices loop](./03-architecture-best-practices-loop.md), which deepens the same lane along a different axis: this option asks more reviewers, that one asks more questions.

« [back to the feature labs](../progression/L3-L5-feature-labs.md) »
