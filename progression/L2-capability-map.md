# L2 · Capability Map

**Lab · 30 minutes on Day 1, 30 minutes on Day 2**

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context](#context)
- [How the lab runs](#how-the-lab-runs)
- [Try It](#try-it)
  - [1. Start the map](#1-start-the-map)
  - [2. Name the layer for each row](#2-name-the-layer-for-each-row)
  - [3. Rank the rows](#3-rank-the-rows)
  - [4. Day 2: finish and review](#4-day-2-finish-and-review)
  - [5. Reflect](#5-reflect)
- [Deliverable](#deliverable)
- [Verification](#verification)
- [Ceiling](#ceiling)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

A **capability map** is a ranked list of the changes you want to make to your factory, each one named, sized, assigned to a layer, and given a test. By the end of this lab you have one committed to your own rig, and the top of it is what you build in the three feature labs.

This is the single most load-bearing artifact of the two days. Everything on Day 2 afternoon consumes it.

## Prereqs

- [L1](./L1-plan-your-factory.md) complete: your repo registered as a rig, the base factory installed in it, a project overview and both manifests written, and at least one real bead slung.

## Context

You could write a list of factory improvements from first principles, and it would be worse than this one. The rows that matter come from two places you now have and did not have yesterday.

**The software factory manifest** says what a factory for your project *should* do. **An hour of contact with your own repo** showed what it currently does. Every gap between those two is a row.

The discipline the map imposes is naming the layer. "The reviews are not good enough" is not actionable. "The architect has no decision records to cite, so it produces opinions" names an agent-layer problem with an obvious first move. Most of the value of this lab is in that translation.

## How the lab runs

Thirty minutes at the end of Day 1 to get the rows down, and thirty on Day 2 morning to finish them and read other people's. Do not aim for a finished map on Day 1. Aim for every row you can think of, however rough, because the ranking is easier when the list is complete.

## Try It

### 1. Start the map

**Copy and paste**

```bash
cp "$SFI_PATH/sf-tutorial/artifacts/docs/capability-map.template.md" "$MY_RIG_PATH/docs/current/capability-map.md"
nano "$MY_RIG_PATH/docs/current/capability-map.md"
```

One row per change you want to make. Each row names the change, which layer it touches, what it costs, and how you will know it worked.

Sources to mine, in the order that produces the best rows:

1. **What your factory did to the vague bead in L1.** Whatever it guessed wrong is a row.
2. **`SOFTWARE_FACTORY_MANIFEST.md`.** Read it line by line and ask "does my factory do this". Every no is a row.
3. **The Day 2 options.** Six of them exist, each solving a problem some factory had. Skim [the menu](./L3-L5-feature-labs.md) and note which ones describe a problem you actually have.
4. **The thing that annoyed you today.** It counts.

Aim for five to eight rows. Fewer than five usually means you have not looked hard at what went wrong in L1. More than eight means Day 2 becomes a list rather than a build.

### 2. Name the layer for each row

Naming the layer is most of the thinking, and it comes straight from the tour in [W4](./W4-tour-the-factory.md).

| Layer | You are changing | Shape of the change |
| --- | --- | --- |
| **Pack** | What capabilities exist at all | One `gc import add`, often of one of the six Day 2 options |
| **Agent** | What an agent knows and how it judges | A prompt template, or an `agent.toml` |
| **Formula** | What steps a job has and what they depend on | A `*.formula.toml`, often an `extends` of an existing one |
| **Order** | When something happens with no human present | An `order.toml` with a `cron`, `cooldown`, `condition` or `event` trigger |

Two rules of thumb. If a row could be satisfied by installing one of the six options, say so in the row — that makes it a first-enhancement candidate and it will take you an hour rather than a day. And if you cannot name a layer, the row is still a symptom rather than a change; keep digging until you can.

### 3. Rank the rows

Put a `1` next to the one you would build first if you only got one, and be honest rather than ambitious. **One finished change beats three half-finished ones**, and you have three lab slots rather than infinite ones.

A useful tiebreak: rank by how much you would trust the factory afterwards, not by how interesting the change is to build.

Commit it:

```bash
cd "$MY_RIG_PATH"
git add docs/current/capability-map.md
git commit -m "Add capability map for factory changes"
```

### 4. Day 2: finish and review

Come back to the map with a night's distance. A new shell has forgotten the variable [L1](./L1-plan-your-factory.md#1-register-your-repo-as-a-rig) exported, so set it again before the commands on this page or in the labs that follow:

```bash
export MY_RIG_PATH="$SFI_PATH/<your-rig-name>"
```

Then three things to do, in order:

**Fill the gaps.** Rows you left as symptoms yesterday, layers you could not name, tests you left blank. The test column is the one people skip; a row with no test is a row you cannot tell you have finished.

**Read someone else's map.** Swap with the person next to you. The useful question to ask about their map is not "is this right" but "which row would you build first, and why is it not the one they ranked 1". Disagreement there is almost always about how much they trust their reviewers, which is the real subject of both days.

**Re-rank.** Your row 1 has to be something you can finish in the first lab slot from the base factory alone. If it is not, either shrink it or promote something that is.

### 5. Reflect

The map is a factory design document that took two days of contact to write and would have been guesswork on day zero. Keep it after the workshop: it is the thing you hand a colleague when they ask what your factory is for.

## Deliverable

`docs/current/capability-map.md`, committed to your rig, with five to eight ranked rows. Every row names a layer and carries a test.

## Verification

```bash
test -f "$MY_RIG_PATH/docs/current/capability-map.md" && echo "capability map: present"
grep -c '^|' "$MY_RIG_PATH/docs/current/capability-map.md"
cd "$MY_RIG_PATH" && git log --oneline -1 -- docs/current/capability-map.md
```

**Expected output**

```text
capability map: present
a row count in the high single digits or low teens, counting the header
a commit
```

## Ceiling

Take your row 1 and write its **acceptance** as a bead in your rig, properly specified, before Day 2 afternoon. Then read it back and ask whether an agent with no context could implement it. If not, you have learned something about your backlog that applies well beyond this workshop.

## Troubleshooting

- **Every row you write is agent-layer.** That is common and usually right at first, because prompts are where judgement lives. Push on it once: ask which rows would be better solved by a step in a formula that runs whether or not the agent remembers.
- **You cannot think of five rows.** Re-read the software factory manifest rather than the code. If it is thin, that is itself row 1: the factory has nothing to hold itself to.
- **The rows are all "install option X".** Fine for row 1, thin as a map. At least two rows should be things no shipped option gives you, because those are the ones that make the factory yours.

## What's next

Day 2's three lab slots build from this map. [L3, L4 and L5](./L3-L5-feature-labs.md) are the same page: the first slot is one of the six shipped options, and the other two are either an option you have not used or a change of your own.

« [previous: L1 Point the Factory at Your Own Project](./L1-plan-your-factory.md) | [next: L3-L5 Feature Labs](./L3-L5-feature-labs.md) »
