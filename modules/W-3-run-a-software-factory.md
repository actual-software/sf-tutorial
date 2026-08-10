# W-3 · Run a Software Factory

« [previous: W-2 What is a Software Factory?](./W-2-what-is-a-software-factory.md) | [next: W-4 Review Loops](./W-4-review-loops.md) »

**Workshop · Wednesday 10:00–11:00 · 60 minutes · one shared example**

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context](#context)
- [How the hour runs](#how-the-hour-runs)
- [Deliverable](#deliverable)
- [Verification](#verification)
- [If you fall behind](#if-you-fall-behind)
- [Ceiling](#ceiling)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

Stand up `factory1`, register the `ascii-art` rig, and drive one bead from sling to merged pull request. By the end of the hour you have a running factory and you have watched it do a complete unit of work.

## Prereqs

- [W-1 Preflight Setup](../progression/00.0-preflight.md) green. Dependencies resolve, `gc` and `bd` are on your `PATH` at the pinned versions.
- A fresh GitHub repo you can push to, in your own org or a sandbox account. The rig pushes to it and W-4 applies branch protection to it.
- `gh` authenticated. Check with `gh auth status`.

## Context

Nothing in this block is new material. It is four existing progression pages run back to back at pace, and the pace is the point: sixty minutes is tight for four pages, and it is tight on purpose.

**This hour assumes you did the pre-work.** Everyone was asked to run through the `actual-factory-demo` repo before the workshop. That repo covers the same ground this block covers, in different words, so if you did it the commands here will feel like a second pass rather than a first one. If you skipped it, say so at the start rather than at 10:45 — an instructor will pair with you, and the [catch-up script](#if-you-fall-behind) exists precisely for this.

The vocabulary mapping between what the demo repo calls things and what this tutorial calls them was covered in [W-2](./W-2-what-is-a-software-factory.md). Keep that mapping open if the words drift.

## How the hour runs

Four pages, in order. The timings are guidance, not a gate.

| Minutes | Page | What you get |
| --- | --- | --- |
| 10:00–10:15 | [`00.1` Create a Gas City named factory1](../progression/00.1-setup-foundation.md) | `factory1` exists, the setup pack is installed, the `polecat` and `refinery` agents are available, Dolt is supervisor-managed |
| 10:15–10:35 | [`00.2` Add the ASCII Art rig](../progression/00.2-setup-foundation.md) | The rig registered and pushed to your GitHub repo, locked docs in place, 138 beads seeded |
| 10:35–10:40 | [`00.3` Env vars for fresh shells](../progression/00.3-setup-foundation.md) | Four exports persisted to your shell rc so a new terminal does not cost you five minutes |
| 10:40–11:00 | [`01` Basic flow](../progression/01-basic-flow.md) | Three letters landed on `main` through real pull requests, each approved by the refinery |

Do not skip `00.3`. It is the shortest page in the repo and it is the one that stops the rest of the day from being an exercise in re-deriving paths.

`01` is where the factory actually runs. One polecat claims a bead and implements it, one refinery reviews and publishes a pull request, and you merge by hand. That merge stays manual for now. W-4 is where it becomes manual *by policy* rather than by convention.

## Deliverable

A `factory1` city with the `ascii-art` rig registered, and at least one letter merged to `main` through a pull request the refinery opened.

You do not need all three letters from `01`. One is enough to have seen the loop; the other two are repetition, and repetition is what the break is for.

## Verification

```bash
gc status
bd list --status closed --limit 5
gh pr list --state merged --limit 5
```

`gc status` should show the controller running. `bd` should show at least one closed bead, and `gh` at least one merged pull request against your rig repo.

## If you fall behind

```bash
cd path/to/sf-tutorial/bootstrap
./bootstrap.sh 01-basic-flow
```

That rebuilds `factory1` and `ascii-art` through the end of `01`, which is exactly this block's end state. Run it over the break and you start W-4 on the same line as everyone else.

Read [the bootstrap README](../bootstrap/README.md) before you run it. The script is destructive by design: it tears down and rebuilds `factory*/`, `ascii-art/` and `sf-tutorial/` inside your workspace, and it wants a capital `Y` at the prompt.

## Ceiling

Finished early? Two things worth your time, in this order.

Sling a bead and then watch the agents work rather than watching the bead state. `gc session list` shows you who is alive, and attaching to a session shows you what it is actually reasoning about. W-6 makes a proper session out of this, but the first look is more interesting when you have not been told what to expect.

Then open `city.toml` and the setup pack side by side and find where the polecat's prompt comes from. Every later block edits configuration in that shape, and knowing where the file lives makes the rest of the two days faster.

## Troubleshooting

- **`gc status` shows `Controller: stopped` and `bd` says Dolt is unreachable.** Page [`00.1`](../progression/00.1-setup-foundation.md) has the full recovery sequence in its own troubleshooting section. This is the single most common Wednesday-morning failure and it is fixable in under a minute.
- **`00.2` fails at the push step.** The rig repo has to exist and be empty. If you created it with a README, either delete that commit or point the rig at a genuinely fresh repo.
- **A new terminal has none of the paths.** You skipped `00.3` step 3. Run it now.

## What's next

The factory runs, but nothing forces it to be careful. [W-4 Review Loops](./W-4-review-loops.md) turns review into a gate the factory cannot route around.

« [previous: W-2 What is a Software Factory?](./W-2-what-is-a-software-factory.md) | [next: W-4 Review Loops](./W-4-review-loops.md) »
