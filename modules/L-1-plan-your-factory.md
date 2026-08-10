# L-1 · Plan Your Factory

« [previous: W-6 Coordination Channels](./W-6-coordination-channels.md) | [next: W-7 The Mayor and Workflows](./W-7-mayor-and-workflows.md) »

**Lab · Wednesday 4:00–5:00 · 60 minutes · your own project**

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context](#context)
- [How the lab runs](#how-the-lab-runs)
- [Try It](#try-it)
  - [1. Register your repo as a rig](#1-register-your-repo-as-a-rig)
  - [2. Write a project manifest](#2-write-a-project-manifest)
  - [3. Get real beads in](#3-get-real-beads-in)
  - [4. Write the capability map](#4-write-the-capability-map)
  - [5. Reflect](#5-reflect)
- [Deliverable](#deliverable)
- [Verification](#verification)
- [Ceiling](#ceiling)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

By the end of this hour your factory points at your own repository rather than at `ascii-art`, it has a project manifest describing what that repository is, it has real beads in the queue, and you have written a **capability map** of the changes you want to make. Tomorrow afternoon is when you build from that map, so it is the deliverable that matters most.

## Prereqs

- Wednesday morning complete: `factory1` running with the gates from [W-4](./W-4-review-loops.md) and [W-5](./W-5-requirement-gates.md).
- A repository you can push to and are willing to let a factory open pull requests against. A personal project or a fork is ideal. A repository you do not control is not.
- The four env vars from [`00.3`](../progression/00.3-setup-foundation.md) exported.

## Context

Everything so far has run against `ascii-art`, a project chosen because it is boring. The rules are simple, the acceptance criteria are unambiguous, and nothing in it is load-bearing for anyone. That is what made the morning teachable.

Your project is not boring, and that is where the interesting failures live. Two of them show up in the first ten minutes and it is worth expecting them:

**Your beads will be vaguer than `ascii-art`'s.** The seeded beads say things like "create `e.md` with the letter E and a rhyme". Yours will say "improve error handling in the sync path". The gate from W-5 will bounce the second one, correctly, and that bounce is the most useful thing that happens this hour.

**Your reviewers have nothing to cite.** The architect from W-4 reads decision records. If your repo has none, the reviewer produces opinions rather than verdicts. You do not have to fix that today. You do have to notice it, because it goes on the capability map.

The point of the hour is not a finished factory. It is a factory pointed at real work, plus a written, prioritised list of what to do about what you find.

## How the lab runs

Sixty minutes, participant-led, instructor circulating. Spend at most thirty on steps 1 to 3 and leave a full twenty for step 4. If you run out of time, the capability map is the part to protect.

## Try It

### 1. Register your repo as a rig

Register the rig as a **sibling** of the city, the same shape as [`00.2`](../progression/00.2-setup-foundation.md) used for `ascii-art`.

**Copy and paste**

```bash
cd "$FACTORY_PATH"
git clone <your-repo-url> ../<your-rig-name>
gc rig add ../<your-rig-name> <your-rig-name>
export MY_RIG_PATH="$(cd ../<your-rig-name> && pwd)"
echo "$MY_RIG_PATH"
gc rig list
```

**Expected output**

```text
your rig listed alongside ascii-art, with a path and a prefix
```

Add `MY_RIG_PATH` to your shell rc the same way [`00.3`](../progression/00.3-setup-foundation.md) did for the other four. You will want it tomorrow.

### 2. Write a project manifest

The manifest is how agents learn what your project is before they touch it. Without one, every agent re-derives your conventions from the code, badly and differently each time.

**Copy and paste**

```bash
mkdir -p "$MY_RIG_PATH/docs/current"
cp "$ARTIFACTS_PATH/docs/PROJECT_MANIFEST.template.md" "$MY_RIG_PATH/PROJECT_MANIFEST.md"
$EDITOR "$MY_RIG_PATH/PROJECT_MANIFEST.md"
```

Fill in what a competent new colleague would need on day one, and nothing more. Ten honest lines beat three pages of aspiration. The sections that earn their place are the stack, how to run the tests, what must never break, and where the conventions are written down.

Commit it:

```bash
cd "$MY_RIG_PATH"
git add PROJECT_MANIFEST.md
git commit -m "Add project manifest for factory agents"
```

### 3. Get real beads in

**Copy and paste**

```bash
cd "$MY_RIG_PATH"
bd status
```

If that errors with `no beads database found`:

```bash
bd init --prefix <your-rig-name>
```

Now create three beads by hand. Real ones, from your actual backlog:

```bash
bd create --title "<something you genuinely want done>" --type task --priority 2
bd create --title "<something small and well-specified>" --type task --priority 2
bd create --title "<something you would struggle to explain to a new hire>" --type task --priority 3
```

The third one is deliberate. Sling it at the gate and watch what happens:

```bash
cd "$FACTORY_PATH"
gc sling project-manager <the-third-bead-id>
bd show <the-third-bead-id> --json | jq -r '.[0] | .status, .metadata.blocker_reason // "no blocker"'
```

If the gate bounced it, read the feedback. That feedback is a description of what your backlog does to a new engineer, and it is the first line of your capability map.

### 4. Write the capability map

This is the deliverable. Twenty minutes, and do not skip it because the rig is more fun.

**Copy and paste**

```bash
cp "$ARTIFACTS_PATH/docs/capability-map.template.md" "$MY_RIG_PATH/docs/current/capability-map.md"
$EDITOR "$MY_RIG_PATH/docs/current/capability-map.md"
```

The map has one row per change you want to make to your factory. Each row names the change, which of the three layers it touches, what it costs, and how you will know it worked.

The three layers come from [W-7](./W-7-mayor-and-workflows.md) tomorrow morning, and naming the layer is most of the thinking:

| Layer | You are changing | Shape of the change |
| --- | --- | --- |
| **Agent** | What an agent knows and how it judges | A prompt template, an `agent.toml` |
| **Formula** | What steps a job has and what they depend on | A `*.formula.toml`, often an `extends` of an existing one |
| **Order** | When something happens with no human present | An `order.toml` with a `cooldown`, `cron`, `condition` or `event` trigger |

Aim for five to eight rows. Fewer than five usually means you have not looked hard at what went wrong in step 3; more than eight means tomorrow will be a list rather than a build.

Then rank them. Put a `1` next to the one you would build first if you only got one, and be honest rather than ambitious: tomorrow's L-5 block is ninety minutes, and one finished change beats three half-finished ones.

Commit the map:

```bash
cd "$MY_RIG_PATH"
git add docs/current/capability-map.md
git commit -m "Add capability map for factory changes"
```

### 5. Reflect

You now have a factory pointed at real work and a written list of what it cannot yet do. That list came from an hour of contact with your own repo, which is why it is better than a list you would have written yesterday from first principles.

Tomorrow morning is machinery: [W-7](./W-7-mayor-and-workflows.md) covers the three layers your map is written in. Tomorrow afternoon, [L-5](./L-5-implement-a-feature.md) is where you build the top of the list.

## Deliverable

`docs/current/capability-map.md`, committed to your rig, with five to eight ranked rows.

A registered rig and a manifest are the supporting cast. The map is the thing L-5 consumes.

## Verification

```bash
gc rig list
test -f "$MY_RIG_PATH/PROJECT_MANIFEST.md" && echo "manifest: present"
test -f "$MY_RIG_PATH/docs/current/capability-map.md" && echo "capability map: present"
cd "$MY_RIG_PATH" && bd list --status open
```

## Ceiling

Sling your *well-specified* bead (the second one) all the way through to a pull request and read the diff properly. Not to merge it, but to answer one question: would you have written it that way?

Whatever the answer is, it belongs on the capability map as a row. "The implementer does not know we use X" is an agent-layer change. "Nobody checked the tests ran" is a formula-layer change. That single read produces better rows than any amount of thinking about the factory in the abstract.

## Troubleshooting

- **`gc rig add` fails because the directory already exists with content.** That is fine and expected for a cloned repo; the command adopts the directory. If it refuses, check you passed the path as a sibling of the city rather than a path inside it.
- **`bd init` refuses because the prefix collides.** Two rigs cannot share a prefix. Pass a distinct one with `--prefix`.
- **The gate passes your deliberately-vague bead.** Your bead was better than you thought, or the gate's checklist does not cover the ambiguity you had in mind. Both are capability-map rows.
- **You do not have a repo you can push to.** Fork something you know well, or use a scratch repo and pick beads you could plausibly implement in it. The mechanics are the lesson; the codebase is the setting.

## What's next

[W-7 The Mayor and Workflows](./W-7-mayor-and-workflows.md) opens Thursday with the machinery your capability map is written against.

« [previous: W-6 Coordination Channels](./W-6-coordination-channels.md) | [next: W-7 The Mayor and Workflows](./W-7-mayor-and-workflows.md) »
