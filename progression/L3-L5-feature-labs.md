# L3, L4 and L5 · Feature Labs

**Three labs · 45 to 60 minutes each · Day 2**

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [The three slots, and what each allows](#the-three-slots-and-what-each-allows)
- [The six options](#the-six-options)
- [How each lab runs](#how-each-lab-runs)
- [Try It](#try-it)
  - [1. Pick from the map](#1-pick-from-the-map)
  - [2. Build it](#2-build-it)
  - [3. Prove it worked](#3-prove-it-worked)
  - [4. Put it behind a gate](#4-put-it-behind-a-gate)
  - [5. Reflect](#5-reflect)
- [Deliverable](#deliverable)
- [Verification](#verification)
- [Ceiling](#ceiling)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

Three slots, three changes to your own factory, each one verified. This page serves all three; what differs between them is what you are allowed to pick.

## Prereqs

- [L2](./L2-capability-map.md) complete: a ranked capability map committed to your own rig.
- Your own rig registered and carrying the base factory.

## The three slots, and what each allows

| Slot | You may build |
| --- | --- |
| **L3** | One of the six options below. Nothing else. |
| **L4** | An option you have not used yet, **or** a feature of your own from the map. |
| **L5** | Same as L4: an option you have not used yet, or a feature of your own. |

L3 is constrained on purpose. Each option is a worked, tested capability with a page explaining what problem it solves, so the first slot buys you a working extension and a model to copy. The two later slots are where the factory becomes yours.

**Every option installs on the base factory alone.** None requires another, none has to be done in order, and you never remove one to add the next. Pick on the basis of which problem you actually have.

## The six options

| Option | Solves | Pack |
| --- | --- | --- |
| [Bead gate checks](../hardening/06-bead-gate-checks.md) | Work reaches an implementer under-specified and it has to guess | `bead-gate-rig` |
| [Bead creation formula extensions](../hardening/01-bead-creation-formula-extensions.md) | Beads arrive with no design, test or docs thinking attached | `bead-builders-rig` |
| [Specialized domain reviewers](../hardening/02-specialize-reviewers-per-domain.md) | One reviewer judging everything reviews nothing well | `domain-reviewers-rig` |
| [Architecture best-practices loop](../hardening/03-architecture-best-practices-loop.md) | Reviews are opinions rather than scores against named principles | `principles-loop-rig` |
| [Strengthen the review system](../hardening/04-strengthen-review-system.md) | One model is one point of view, and it is confidently wrong sometimes | `multi-vendor-rig` |
| [Self-improvement loop](../hardening/05-self-improvement-loop.md) | The factory produces evidence about itself and nobody reads it | none — it is a loop, not a pack |

If your rank-1 row said "install option X", this is where you find X. If it did not, L3 is still an option slot: pick the one whose problem statement is closest to a row on your map.

## How each lab runs

Participant-led, no shared end state. The instructor circulates; say which layer you are working in when they reach you, because the failure modes differ per layer and pairing works best within one.

A slot is enough to build one change properly. It is not enough for two. The ranking you did in L2 is what makes that survivable.

## Try It

### 1. Pick from the map

**Copy and paste**

```bash
cd "$MY_RIG_PATH"
nano docs/current/capability-map.md
```

Re-rank if the morning changed your mind, and commit the re-rank before you build. A map with a stale ranking is a map you will stop trusting.

Then commit to one row out loud, to yourself or to whoever you are pairing with, in this shape:

> I am changing the **\<pack | agent | formula | order\>** layer so that **\<the factory does X\>**, and I will know it worked when **\<the verification from the map's own column\>**.

If you cannot fill that sentence in, the row is not ready and the next one probably is.

### 2. Build it

**If you picked an option**, its page carries the install and the walkthrough. Every option is a single import onto the base factory:

```bash
cd "$FACTORY_PATH"
gc import add --rig <your-rig-name> "$ARTIFACTS_PATH/packs/<the-option-pack>"
gc reload
gc import list --rig <your-rig-name>
```

Then follow that page's Try It against your own rig rather than `ascii-art`.

**If you are building your own**, where you work depends on the layer, and each has a worked example in the repo to copy the shape from.

**Agent layer.** You are changing what an agent knows or how it judges. The files are a prompt template and an `agent.toml` under a pack's `agents/<name>/`. Most agent-layer changes are prompt edits, and the highest-value edit is almost always giving a reviewer a real document to cite rather than more adjectives.

**Formula layer.** You are changing what steps a job has. The files are `*.formula.toml` under a pack's `formulas/`. Copy [`mol-polecat-pr`](../artifacts/packs/pr-gate-rig/formulas/mol-polecat-pr.formula.toml) specifically, because it uses `extends` to replace exactly one step of a base formula and inherit the rest. Reach for `extends` before writing a formula from scratch: a short diff is easier to debug and it does not fork the base.

**Order layer.** You are changing when something happens. The file is an `order.toml` with one trigger. Use `condition` when the factory should react to its own bead store, `cron` or `cooldown` for a proactive sweep, `event` to react to something the factory announced. The two in [`base-factory/orders/`](../artifacts/packs/base-factory/orders/) are deliberately minimal and are the easiest shape to copy.

Whichever layer, reload and check before you test:

```bash
cd "$FACTORY_PATH"
gc reload
gc doctor
```

### 3. Prove it worked

Run the verification you wrote in the map's own column, not a different one that is easier to satisfy.

**Copy and paste**

```bash
cd "$MY_RIG_PATH"
bd create --title "<a bead that exercises the change>" --type task --priority 2
cd "$FACTORY_PATH"
gc sling --rig <your-rig-name> polecat <the-new-bead-id>
watch -n 5 'cd '"$MY_RIG_PATH"' && bd show <the-new-bead-id> --json | jq -r ".[0] | \"\(.status)  \(.assignee)\""'
```

The important part is the negative case. **A gate you have only seen pass is a gate you have not tested.** Construct the input that *should* be rejected and confirm it is:

```bash
cd "$MY_RIG_PATH"
bd create --title "<a bead your change should reject or catch>" --type task --priority 3
cd "$FACTORY_PATH"
gc sling --rig <your-rig-name> polecat <that-bead-id>
cd "$MY_RIG_PATH"
bd show <that-bead-id> --json | jq -r '.[0] | .status, (.metadata.blocker_reason // "no blocker recorded")'
```

If both cases behave, the row is done. Mark it in the map and move on.

### 4. Put it behind a gate

A capability that can be skipped is a suggestion. If your change is a check, make it block; if it is a step, make something depend on it.

Applied concretely: after your change there is an input for which the factory stops and says why. Confirm the failure is legible rather than merely present:

```bash
bd show <the-rejected-bead-id> --json | jq -r '.[0].metadata'
```

A blocked bead with no reason recorded is a stall rather than a gate. If the reason field is empty, that is your next edit.

### 5. Reflect

You have changed a factory on the basis of evidence it produced about itself. That loop, rather than any single change, is the thing worth taking home.

Two questions before the slot ends. Which layer did the change land in, and was that the layer you predicted in L2? And what did building it add to the map that was not there this morning?

Write the second answer into the map now. It is the first row of the next version of this exercise, and unlike today you will not have a room full of people to help you rediscover it.

## Deliverable

Per slot: one capability-map row built, verified on both the positive and the negative case, and committed to your rig.

Across the three slots: at least one shipped option installed and working in your own rig, and at least one change nobody handed you.

## Verification

```bash
cd "$FACTORY_PATH"
gc import list --rig <your-rig-name>
gc doctor
cd "$MY_RIG_PATH"
git log --oneline -3
bd list --status blocked
```

**Expected output**

```text
the option you installed among the rig's imports
no errors from doctor
your commits from this slot
the bead you deliberately made fail, still blocked with a reason
```

## Ceiling

Make what you built survive someone else. Write the three sentences explaining it into your rig's docs, so a colleague reading the file in a month knows why it exists.

That is also most of the work for [W7](./W7-sharing-your-factory.md) already done.

## Troubleshooting

- **The option's page refers to agents you do not have.** Each option page assumes the base factory plus that option. If it names an agent from a different option, you found a bug worth reporting; the options are meant to be independent.
- **`gc import add` succeeds and the new agent never appears.** Check the scope. Options install at rig scope with `--rig`; installing at city scope puts the agent somewhere the rig cannot see.
- **Your change works on `ascii-art` and not on your rig.** Your rig needs the base factory imported too — L1 step 1. `gc import list --rig <your-rig-name>` settles it.
- **The negative case passes when it should fail.** Either the input was better-formed than you thought, or the check is not on the path the bead took. Both are worth a map row.

## What's next

After L3 comes [W6](./W6-advanced-concepts.md); after L4 comes [W7](./W7-sharing-your-factory.md); after L5 comes the wrap-up.

« [previous: L2 Capability Map](./L2-capability-map.md) | [next: W6 Advanced Concepts](./W6-advanced-concepts.md) »
