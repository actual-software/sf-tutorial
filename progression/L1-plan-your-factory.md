# L1 · Point the Factory at Your Own Project

**Lab · 45 minutes · Day 1**

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context](#context)
- [How the lab runs](#how-the-lab-runs)
- [Try It](#try-it)
  - [1. Register your repo as a rig](#1-register-your-repo-as-a-rig)
  - [2. Write a project overview](#2-write-a-project-overview)
  - [3. Generate the two manifests](#3-generate-the-two-manifests)
  - [4. Get real beads in](#4-get-real-beads-in)
  - [5. Reflect](#5-reflect)
- [Deliverable](#deliverable)
- [Verification](#verification)
- [Ceiling](#ceiling)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

By the end of this lab your factory points at your own repository rather than at `ascii-art`, that repository has a project overview and the two generated manifests describing what it is and what a factory for it should do, and there are real beads from your actual backlog in its queue.

That set of documents is the input to [L2](./L2-capability-map.md), which starts right after this and is the deliverable that matters most.

## Prereqs

- [W3](./W3-run-your-factory.md) through [W5](./W5-observability.md) complete: a working factory you can read.
- A repository you can push to and are willing to let a factory open pull requests against. A personal project or a fork is ideal. A repository you do not control is not.
- The four env vars exported.

## Context

Everything so far has run against `ascii-art`, a project chosen because it is boring. The rules are simple, the acceptance criteria are unambiguous, and nothing in it is load-bearing for anyone. That is what made it teachable.

Your project is not boring, and that is where the interesting failures live. Two of them show up in the first ten minutes and are worth expecting:

**Your beads will be vaguer than `ascii-art`'s.** The seeded beads say things like "create `e.md` with the letter E and a rhyme". Yours will say "improve error handling in the sync path". Watch what your factory does with the second kind, because that difference is the first line of your capability map.

**Your reviewers have nothing to cite.** The architect reads decision records. If your repo has none, it produces opinions rather than verdicts. You do not have to fix that today. You do have to notice it.

The point of the lab is not a finished factory. It is a factory pointed at real work, and enough written description of that work to reason about what the factory is missing.

## How the lab runs

Forty-five minutes, participant-led, instructor circulating. Steps 1 and 2 are quick. Step 3 is the one that takes real time, because the manifest generator asks you questions about your own project that you may not have answered before.

## Try It

### 1. Register your repo as a rig

Register the rig as a **sibling** of the city, the same shape [W3](./W3-run-your-factory.md) used for `ascii-art`.

**Copy and paste**

```bash
cd "$SFI_PATH/factory1"
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

Then install the base factory into it, so your own rig has the same machinery `ascii-art` does:

**Copy and paste**

```bash
gc import add --rig <your-rig-name> "$SFI_PATH/sf-tutorial/artifacts/packs/base-factory"
gc import list --rig <your-rig-name>
```

### 2. Write a project overview

A **project overview** is a loosely structured document answering a few questions about what your project is and who it is for. It is the input the manifest generator reads, so it is worth twenty honest sentences rather than five careful ones.

**Copy and paste**

```bash
mkdir -p "$MY_RIG_PATH/docs/current"
cp "$SFI_PATH/sf-tutorial/artifacts/docs/PROJECT_OVERVIEW.template.md" "$MY_RIG_PATH/docs/PROJECT_OVERVIEW.md"
nano "$MY_RIG_PATH/docs/PROJECT_OVERVIEW.md"
```

`nano` ships with the box and is not modal: `Ctrl-O` then `Enter` saves, `Ctrl-X` exits. Use a different editor if you prefer one.

### 3. Generate the two manifests

Install the [Manifest Generator skill](https://github.com/audiojak/manifest-generator):

```bash
cd "$MY_RIG_PATH/docs"
npx skills add https://github.com/audiojak/manifest-generator
```

Each coding agent reads skills from its own location — Claude Code from `.claude/skills`, others elsewhere. Select the install option matching your agent, then choose the installation scope and method (symlink is recommended).

Invoke it inside a session with your coding agent:

```bash
# Claude Code:
claude /manifest-generator
# Or invoke /manifest-generator inside whichever CLI coding agent you use.
```

It will ask you questions and produce two files in `docs/`:

- **`PROJECT_MANIFEST.md`** — what the project is: its domain, its architecture, its conventions, its testing story.
- **`SOFTWARE_FACTORY_MANIFEST.md`** — what a factory for it should do: which gates matter here, what a reviewer should cite, what must never be automated.

The second one is the one people skip and then need. It is the document your capability map argues with in the next lab.

### 4. Get real beads in

**Copy and paste**

```bash
cd "$MY_RIG_PATH"
bd status
```

Now create three beads by hand. Real ones, from your actual backlog:

```bash
bd create --title "<something you genuinely want done>" --type task --priority 2
bd create --title "<something small and well-specified>" --type task --priority 2
bd create --title "<something you would struggle to explain to a new hire>" --type task --priority 3
```

The third one is deliberate. Sling it and watch what your factory does with an under-specified ask:

```bash
cd "$SFI_PATH/factory1"
gc sling --rig <your-rig-name> polecat <the-third-bead-id>
```

Then watch it, from your own rig:

```bash
cd "$MY_RIG_PATH"
bd show <the-third-bead-id> --json | jq '.[0] | {status, assignee, metadata}'
```

**What to notice.** Your base factory has no gate in front of the polecat, so the vague bead goes straight to an implementer that has to guess. Read what it guessed. Whatever went wrong there is a capability-map row, and one of the Day 2 options exists precisely to put a gate in that position.

### 5. Reflect

You have a factory pointed at real work and two documents describing what that work is. The gap between what the software factory manifest says your factory should do and what it actually does is the subject of the next lab.

## Deliverable

`docs/PROJECT_OVERVIEW.md`, `docs/PROJECT_MANIFEST.md` and `docs/SOFTWARE_FACTORY_MANIFEST.md` in your own rig, plus three real beads in its queue and at least one of them slung.

## Verification

```bash
gc rig list
gc import list --rig <your-rig-name>
test -f "$MY_RIG_PATH/docs/PROJECT_MANIFEST.md" && echo "project manifest: present"
test -f "$MY_RIG_PATH/docs/SOFTWARE_FACTORY_MANIFEST.md" && echo "factory manifest: present"
cd "$MY_RIG_PATH" && bd list --status open
```

## Ceiling

Sling your *well-specified* bead (the second one) all the way through to a pull request and read the diff properly. Not to merge it, but to answer one question: would you have written it that way?

Whatever the answer is, it becomes a capability-map row in the next lab. "The implementer does not know we use X" is an agent-layer change. "Nobody checked the tests ran" is a formula-layer change. That single read produces better rows than any amount of thinking about the factory in the abstract.

## Troubleshooting

- **`gc rig add` fails because the directory already exists with content.** That is fine and expected for a cloned repo; the command adopts the directory. If it refuses, check you passed the path as a sibling of the city rather than a path inside it.
- **`bd init` refuses because the prefix collides.** Two rigs cannot share a prefix. Pass a distinct one with `--prefix`.
- **The manifest generator produces something thin.** It is reading your project overview. Go back to step 2 and answer the questions properly; the generator cannot know what you did not write down.
- **You do not have a repo you can push to.** Fork something you know well, or use a scratch repo and pick beads you could plausibly implement in it. The mechanics are the lesson; the codebase is the setting.

## What's next

[L2](./L2-capability-map.md) turns those documents into a ranked list of changes you want to make to your factory. It starts now and finishes on Day 2 morning.

« [previous: W5 Observability and Traceability](./W5-observability.md) | [next: L2 Capability Map](./L2-capability-map.md) »
