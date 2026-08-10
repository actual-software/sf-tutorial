# W-4 · Intro to Software Factories: Review Loops

« [previous: W-3 Run a Software Factory](./W-3-run-a-software-factory.md) | [next: W-5 Requirement Gates](./W-5-requirement-gates.md) »

**Workshop · Wednesday 11:00–12:00 · 60 minutes · one shared example**

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context: three governance requirements](#context-three-governance-requirements)
- [How the hour runs](#how-the-hour-runs)
- [Deliverable](#deliverable)
- [Verification](#verification)
- [If you fall behind](#if-you-fall-behind)
- [Ceiling](#ceiling)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

Turn review from something the factory does into something the factory cannot skip. By the end of the hour a bead cannot become a pull request without a round of feedback, a pull request cannot reach `main` without a human, and an architecture reviewer sits between the two.

## Prereqs

- [W-3](./W-3-run-a-software-factory.md) complete: `factory1` running, `ascii-art` registered, at least one letter merged through a pull request.
- You own the rig's GitHub repo, or have admin on it. Branch protection is an owner-level operation.
- `jq` installed. The review-loop formula uses it.

## Context: three governance requirements

Read this before you open the first page, because the three pages in this block are much easier to hold in your head as answers to three questions than as three unrelated features.

Any organisation that wants to let agents write code eventually writes down some version of these:

1. **An unresolved blocking check must prevent work from being marked ready.** Not "should warn". Prevent.
2. **A consequential decision needs either a deterministic gate or a named human who owns it.** A model may not approve work or sign on behalf of a person.
3. **The system must fail visibly when evidence is missing or ambiguous**, rather than proceeding on the assumption that silence means success.

That is a governance posture, and it is the thing most teams cannot currently demonstrate about their agent setups. This hour is where the factory earns it. Page `02` answers the first, `03` answers the second, and `04` is the shape of an automated check that produces real evidence rather than a rubber stamp.

This block is also the strongest material in the repo. If you take one thing back to your own team, it is probably this hour.

## How the hour runs

Three pages, in order. No new artifacts to author; every pack you need is already in `artifacts/`.

| Minutes | Page | The requirement it answers |
| --- | --- | --- |
| 11:00–11:20 | [`02` First review loop](../progression/02-first-review-loop.md) | A required round of feedback before any bead becomes a pull request |
| 11:20–11:40 | [`03` Branch protection](../progression/03-branch-protection.md) | Merge to `main` is human-only, and a direct push is rejected in front of you |
| 11:40–12:00 | [`04` Architect agent](../progression/04-adr-reviewer.md) | Every bead reviewed against the rig's ADRs before the merge gate runs |

Two moments in the hour are worth slowing down for, because they are the ones people remember.

In `03`, step 3 of Try It pushes directly to `main` and watches GitHub refuse it. Run that step even though it fails. The rejection is the deliverable, and reading the error is what makes the gate feel real rather than theoretical.

In `04`, the optional step 8 slings a bead the architect will reject. Do it if you have the minutes. Watching a reviewer produce a reasoned verdict against a document you can open is the difference between "the agent said no" and "the agent cited the ADR". That distinction is the one the third governance requirement is about.

## Deliverable

A factory where the path from bead to `main` has three checkpoints the factory cannot route around: a mandatory feedback round, an architecture verdict, and a human merge.

Write down which of the three you would have the hardest time explaining to your own reviewers. That is a useful thing to carry into [L-1](./L-1-plan-your-factory.md) this afternoon.

## Verification

```bash
gh api "repos/:owner/ascii-art/branches/main/protection" --jq '.required_pull_request_reviews.require_code_owner_reviews'
bd show <bead-id> --json | jq '.[0].metadata.review_loops'
gc rig show ascii-art
```

Expect `true` from the first command, `1` or higher from the second on any bead that has been through the loop, and the `architect-rig` pack listed by the third.

## If you fall behind

```bash
cd path/to/sf-tutorial/bootstrap
./bootstrap.sh 04-adr-reviewer
```

That is this block's end state. Note the one thing the script cannot replay: it deletes the `main` branch protection rule and the epic ruleset on the remote before rebuilding, and `03` is what re-applies them. If you bootstrap past `03` you still have the protection, because the script replays `03`'s setup too. If you bootstrap to an earlier step, the protection is gone until you get back here.

## Ceiling

Split the block's three gates by cost. Branch protection is free and instant; the architect reviewer costs a model call per bead. Now open [`hardening/02`](../hardening/02-specialize-reviewers-per-domain.md) and read the first two sections without running them. That page splits one reviewer into four parallel ones, which multiplies that cost by four.

The question worth sitting with, and worth bringing to [L-2](./L-2-retargeting-the-rig.md) tomorrow: on your own repo, which changes deserve four reviewers and which deserve none? A factory that reviews everything equally is a factory that is either too slow or too shallow.

## Troubleshooting

- **The protection script says the branch does not exist.** `main` has to be pushed before it can be protected. Finish [`00.2`](../progression/00.2-setup-foundation.md)'s push step first.
- **The refinery publishes a pull request on the first patrol, with no feedback round.** The bead already carries `metadata.review_loops` from an earlier run. Pick a fresh bead, or clear the field.
- **The architect never posts a verdict.** Check that the rig's `docs/decision-records/` actually has the ADR in it. `04` copies it in from `artifacts/`, and skipping that step leaves the reviewer with nothing to review against.

## What's next

Review catches bad work on the way out. [W-5 Requirement Gates](./W-5-requirement-gates.md) catches underspecified work on the way in, which is cheaper.

« [previous: W-3 Run a Software Factory](./W-3-run-a-software-factory.md) | [next: W-5 Requirement Gates](./W-5-requirement-gates.md) »
