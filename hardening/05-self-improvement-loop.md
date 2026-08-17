# Self-Improvement Loop

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context: improving the config, not the artifact](#context-improving-the-config-not-the-artifact)
- [How the lab runs](#how-the-lab-runs)
- [Try It](#try-it)
  - [1. Pick a signal your factory already emits](#1-pick-a-signal-your-factory-already-emits)
  - [2. Let the factory read its own signal](#2-let-the-factory-read-its-own-signal)
  - [3. Have it propose a config change](#3-have-it-propose-a-config-change)
  - [4. Put a gate in front of the proposal](#4-put-a-gate-in-front-of-the-proposal)
  - [5. Reflect](#5-reflect)
- [Deliverable](#deliverable)
- [Verification](#verification)
- [Ceiling](#ceiling)
- [The packaged version of this loop](#the-packaged-version-of-this-loop)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

Close the loop: your factory reads a signal it already produces, proposes a change to its own configuration, and a gate stands between that proposal and it taking effect.

## Prereqs

- [L-3](./03-architecture-best-practices-loop.md) complete, on either track. Track A's audit trail makes the best signal, but any of them work.
- [W-7](../progression/08-mayor-and-workflows.md) complete, because the proposal will land in one of the three layers and you need to be able to name which.
- Your capability map from [L-1](../progression/07-plan-your-factory.md) open.

## Context: improving the config, not the artifact

Every loop you have built so far improves an **artifact**. The review loop in [W-4](../progression/02-first-review-loop.md) improves a diff. The scoring loop in [`hardening/03`](../hardening/03-architecture-best-practices-loop.md) iterates until the diff scores well. Both are loops, both are useful, and both leave the factory exactly as they found it. Run the same bad prompt through them a hundred times and it stays a bad prompt.

This block changes the target. The thing being improved is the **configuration** — an agent's prompt, a formula's steps, an order's trigger — and the evidence is what the factory already wrote down about its own behaviour.

That is a small change in wording and a large change in consequence. A factory that improves artifacts gets you through today's backlog. A factory that improves its configuration gets better at tomorrow's, and the difference compounds.

One thing to be clear-eyed about before you start: a proposal is not a change. The whole reason this is worth doing at all is that the gate in step 4 exists. An agent that can silently rewrite its own instructions is not a self-improving factory, it is an unreviewable one.

## How the lab runs

Forty-five minutes, participant-led. This is the shortest lab and the most conceptual, so it is fine to finish with a written proposal you have not yet merged. That is the honest end state for a first pass.

## Try It

### 1. Pick a signal your factory already emits

You do not need new instrumentation. Your factory has been writing evidence about itself all day. Pick one source, in this order of preference:

**Copy and paste**

```bash
cd "$MY_RIG_PATH"
ls -la docs/reviews/ 2>/dev/null                 # L-3 Track A: per-principle scores
bd list --status blocked --json | jq -r '.[] | "\(.id)  \(.metadata.bead_review_feedback // .metadata.blocker_reason // "")"'
cd "$FACTORY_PATH"
gc order history --limit 20
gc costs 2>/dev/null | head -20
```

Four signals, four different questions. The audit trail says which principles keep scoring badly. The blocked beads say what your gate keeps rejecting, which is a description of how your team writes work. Order history says what fired and what did not. Costs say where the money goes.

Pick the one with the most repetition in it. A single bad score is noise; the same rejection four times is a finding.

### 2. Let the factory read its own signal

Rather than reading the signal yourself, hand it to an agent and ask for the pattern. The mayor is the natural place, because this is coordination rather than a unit of work.

**Copy and paste**

```bash
cd "$FACTORY_PATH"
gc session attach mayor
```

Ask it something close to this, in your own words:

> Read the last twenty blocked beads in this rig and their `bead_review_feedback`. What is the most common reason work gets rejected, and is that a problem with how we write beads or with how the gate is written?

Detach with `Ctrl-b` then `d`.

**What to notice.** The second half of that question is the important half. The same evidence supports two opposite conclusions, and which one you accept decides which layer you change. If your beads are genuinely vague, the fix is upstream of the factory. If the gate is over-strict, the fix is the gate's prompt.

### 3. Have it propose a config change

Now ask for a proposal in a shape you can act on. A proposal that names a file and a diff is worth more than a paragraph of advice.

Ask the mayor to write its proposal as a bead, so it lands somewhere durable rather than in a tmux buffer:

```bash
cd "$MY_RIG_PATH"
bd create --title "Proposal: <the change, in one line>" \
  --description "Signal: <what the factory observed about itself, with counts>.
Layer: <agent | formula | order>.
File: <the exact path this change touches>.
Change: <what to do>.
How we will know it worked: <the observable outcome>.
Risk: <what this makes worse>." \
  --type task --priority 3
```

**What to notice.** Writing the proposal as a bead is not bookkeeping. It puts the proposal into the same system every other piece of work goes through, which means the gate you built in [W-5](../progression/05.1-bead-gate-checks.md) will now judge it. A proposal that cannot survive your own front gate is not ready to change your factory.

### 4. Put a gate in front of the proposal

This is the step that makes the loop safe, and it is the one people skip.

**Copy and paste**

```bash
cd "$FACTORY_PATH"
gc sling project-manager <the-proposal-bead-id>
bd show <the-proposal-bead-id> --json | jq -r '.[0] | .status, (.metadata.bead_review_feedback // "passed")'
```

Then add the human. Whatever the verdict, a config change gets a named person, and the mechanism you already have for that is branch protection from [`03`](../progression/03-branch-protection.md): your factory's configuration lives in files, those files live in a repo, and a change to them is a pull request somebody approves.

Say the rule out loud and write it into your capability map:

> A proposal my factory generates may become a pull request automatically. It may not become a merge automatically.

**What to notice.** That sentence is the whole safety model, and it is the same one from [W-4](../progression/02-first-review-loop.md) applied to a new target. A consequential decision needs either a deterministic gate or a named human. "The factory changed its own prompt because it decided to" has neither.

### 5. Reflect

You now have a loop where the factory's own output is an input to its configuration, with a human at the point of effect.

The honest caveat is worth stating: this loop is only as good as the signal. A factory that emits nothing but pass verdicts has nothing to learn from, which is a decent argument for keeping the failure paths noisy. Everything you built in [W-5](../progression/05.1-bead-gate-checks.md) and [L-3](./03-architecture-best-practices-loop.md) is what makes this block possible, because those are the blocks that made the factory write down when it was unhappy.

Add one row to your capability map: the signal you wish your factory emitted and does not. That is usually an order-layer change, and [L-5](../progression/09-implement-a-feature.md) is right after this.

## Deliverable

One proposal bead: a signal with counts, a named layer, a file path, an expected outcome, and a stated risk. Gated, and either approved or rejected by you.

Merging it is optional. Having a proposal that survived your own gate is the deliverable.

## Verification

```bash
cd "$MY_RIG_PATH"
bd list --json | jq -r '.[] | select(.title | startswith("Proposal:")) | "\(.id)  \(.status)"'
```

Expect one proposal bead with a status that reflects a real verdict rather than `open`.

## Ceiling

Automate the observation half and leave the decision half alone.

Write an exec order on a `cooldown` trigger that runs your step-1 query and writes the result somewhere you will actually see it. That is a fifteen-minute change and it converts "I looked at the blocked beads once during a workshop" into a signal that arrives on its own.

Stop before automating step 3. A factory that observes itself on a schedule is useful. A factory that proposes on a schedule generates a queue of proposals nobody reads, which is worse than none.

## The packaged version of this loop

If you want the scheduled form rather than the hand-run one, `self-improvement` is this lab as an installable pack:

**Copy and paste**

```bash
cd "$FACTORY_PATH"
gc import add ../sf-tutorial/artifacts/packs/self-improvement
```

It ships a daily order, a six-step audit workflow, and two small scripts. Read [its README](../artifacts/packs/self-improvement/README.md) before installing, because it does cross the line the Ceiling section just drew, and the README says how it answers that: a hard cap of three proposals per pass, silence as the expected daily outcome, and anything needing a judgement call routed to you instead of minted as a fix.

The part worth reading even if you never install it is the order file. It gates on an environment variable, dispatches its workflow directly instead of asking an agent to run it, and takes its cadence from the last completed pass rather than the last time the order fired. Those are three separate traps, and the comments explain each one.

## Troubleshooting

- **The mayor has no useful pattern to report.** Your factory has not run enough work to have a signal yet. Use `ascii-art`'s history instead — the mechanism is the lesson, and the blocked beads from [W-5](../progression/05.1-bead-gate-checks.md) are real evidence about a real gate.
- **The proposal bead fails your own front gate.** That is the system working. Read the feedback and rewrite the proposal; a proposal with no observable outcome is exactly what the test-generation check exists to catch.
- **`gc costs` returns nothing.** Cost reporting depends on the provider and may not be populated for this city. Pick another signal rather than chasing it.
- **You want the factory to apply the change directly.** Do not, today. Get the loop working with a human at the point of effect first, and note the automation as a capability-map row with its risk column filled in.

## What's next

[L-5 Implement a Feature](../progression/09-implement-a-feature.md) is where the capability map stops being a document.

« [previous: L-3 Hardening — Track B, multi-vendor](./04-strengthen-review-system.md) | [next: L-5 Implement a Feature](../progression/09-implement-a-feature.md) »
