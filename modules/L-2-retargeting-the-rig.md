# L-2 · Work on Your Factory: Retargeting the Rig

« [previous: W-7 The Mayor and Workflows](./W-7-mayor-and-workflows.md) | [next: L-3 Hardening](./L-3-hardening.md) »

**Lab · Thursday 10:00–10:45 · 45 minutes · your own project**

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context: what actually has to change](#context-what-actually-has-to-change)
- [How the lab runs](#how-the-lab-runs)
- [Part 1 · Move yesterday's gates onto your rig](#part-1--move-yesterdays-gates-onto-your-rig)
- [Part 2 · Split the reviewer by domain](#part-2--split-the-reviewer-by-domain)
- [Deliverable](#deliverable)
- [Verification](#verification)
- [If you fall behind](#if-you-fall-behind)
- [Ceiling](#ceiling)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

Take the gates you built yesterday on `ascii-art` and run them against your own repo, then split the single reviewer into reviewers that know something about your domains.

## Prereqs

- [L-1](./L-1-plan-your-factory.md) complete: your own repo registered as a rig, a project manifest committed, real beads in the queue.
- [W-4](./W-4-review-loops.md) and [W-5](./W-5-requirement-gates.md) complete on `ascii-art`, so you have a working reference for what you are about to move.
- `gh` authenticated against the org that owns your repo, with enough permission to set branch protection.

## Context: what actually has to change

The source material for this lab is [`hardening/02-specialize-reviewers-per-domain.md`](../hardening/02-specialize-reviewers-per-domain.md), which installs the `domain-reviewers-rig` pack and replaces the single architect from W-4 with four reviewers running in parallel: ADR, design, testing and docs. The refinery fans out, waits for all four, aggregates the verdicts, and routes the bead.

That page is written against `ascii-art`. Everywhere it says `ascii-art`, read "your rig". Three things do not translate by find-and-replace, and they are the whole lab:

**Your rig has different domains.** ADR, design, testing and docs are the four that make sense for a text-generation project. A backend service might want ADR, testing, security and data-migration. A mobile app might want design, accessibility, testing and release. Pick the four that would actually catch something on your codebase, and be willing to run three instead of four.

**Your reviewers need something to review against.** The ADR reviewer on `ascii-art` reads `docs/decision-records/` and `docs/current/`. If your repo has no decision records, the reviewer has nothing to cite and its verdict degrades to an opinion. Either point it at the documents you do have, or accept that this reviewer is weak until you write them.

**Your gates are only as good as your acceptance criteria.** The test-generation check from [W-5](./W-5-requirement-gates.md) reads the bead and asks whether the described behaviour is testable. On `ascii-art` that is easy because the beads are precise. On your repo it will surface how loose your beads are, which is uncomfortable and is the useful part.

## How the lab runs

Fifteen minutes of demo, then thirty in which you do it. The instructor circulates; there is no shared end state to arrive at.

## Part 1 · Move yesterday's gates onto your rig

Work in your own rig directory rather than `ascii-art`.

1. Install the packs your gates need, at rig scope on your rig rather than on `ascii-art`. That is the `review-loop-rig`, `architect-rig` and `bead-gate-rig` from W-4 and W-5.
2. Apply branch protection to your repo, using [`03`](../progression/03-branch-protection.md)'s script as the template. Adjust `CODEOWNERS` so it names people who actually exist in your org.
3. Sling one real bead and watch it go through. Do not pick your hardest bead. Pick one where you already know what the right answer looks like, so you can tell whether the factory got there.

Stop and look at the first verdict properly. On `ascii-art` the reviewers agreed with you because the project is simple. On your repo the first disagreement is information: either the reviewer is wrong and its prompt needs your domain knowledge, or it is right and your bead was vague.

## Part 2 · Split the reviewer by domain

Now run [`hardening/02`](../hardening/02-specialize-reviewers-per-domain.md) against your rig, with your four domains substituted for its four.

The pack ships four agent definitions under `artifacts/packs/domain-reviewers-rig/agents/`. Each is a prompt template plus an `agent.toml`. Renaming a reviewer is a two-file edit; giving it real domain knowledge is a prompt edit, and that is where your thirty minutes go.

Carry the test-generation gate across too. It was built in W-5 on the bead-gate mechanism, so it moves with the `bead-gate-rig` pack rather than with the reviewers, and it is the check most likely to fire on a real backlog.

## Deliverable

Your own rig, running your own beads, through gates you moved yourself: a required review round, a human merge, and reviewers that know something about your domains.

Note down every place where the `ascii-art` version worked and yours did not. That list is the raw material for [L-4](./L-4-self-improvement-loop.md) this afternoon.

## Verification

```bash
gc rig show <your-rig>
bd list --status in_progress
gh pr list --repo <your-org>/<your-repo> --limit 5
```

Expect your rig to list the packs you installed, at least one bead in flight, and a pull request the factory opened rather than one you opened.

## If you fall behind

There is no bootstrap argument for this lab, because the script rebuilds `ascii-art` and your rig is not `ascii-art`. If your own rig is in a state you cannot recover, fall back to running `hardening/02` on `ascii-art` unchanged:

```bash
cd path/to/sf-tutorial/bootstrap
./bootstrap.sh 05.1-bead-gate-checks
```

Then work `hardening/02` as written. You still learn the fan-out mechanics, and you can retarget after the workshop when nothing is on a clock.

## Ceiling

Make one reviewer genuinely expensive and prove it is worth it. Give a single domain reviewer a real specification to read — your API contract, your migration policy, your accessibility standard — and then sling a bead you know violates it. If the reviewer catches the violation and cites the document, you have a gate. If it produces a plausible paragraph that never names the document, you have a rubber stamp, and the fix is in the prompt rather than in the model.

## Troubleshooting

- **The refinery fans out but never aggregates.** One lane never posted a verdict. `gc session list` shows which reviewer is still alive or has died; the refinery is waiting on it by design.
- **Every reviewer passes everything.** Usually the reviewers have no source documents to cite. Check that the paths in each `agent.toml` resolve inside *your* rig, not inside `ascii-art`.
- **Branch protection refuses to apply.** You need admin on the repo. If your org's repo is not yours to protect, fork it for the workshop and retarget the rig at the fork.

## What's next

[L-3 Hardening](./L-3-hardening.md) is the long lab, and you pick which of two directions to take.

« [previous: W-7 The Mayor and Workflows](./W-7-mayor-and-workflows.md) | [next: L-3 Hardening](./L-3-hardening.md) »
