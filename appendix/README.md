# Appendix: building the base factory by hand

These four pages assemble, step by step, the factory that [W3](../progression/W3-run-your-factory.md) now installs with one command. They are off the taught path and they are not obsolete.

The curriculum changed because a room full of people spending the morning assembling a factory is a room that never gets to use one. So the assembly moved into the `base-factory` pack, and W3 installs it. What these pages hold is the reasoning behind each layer, which the pack cannot carry.

| Page | Builds | Pack it became |
| --- | --- | --- |
| [Basic flow](./01-basic-flow.md) | A polecat implementing and a refinery reviewing, and the PR-publish path on top | `setup`, `pr-gate-rig`, `pr-gate-city` |
| [First review loop](./02-first-review-loop.md) | The review loop, and the three governance rules the rest of the curriculum leans on | `review-loop-rig` |
| [Branch protection](./03-branch-protection.md) | The merge gate on GitHub's side | none — it configures the repo |
| [Architect agent](./04-adr-reviewer.md) | An agent that reviews a diff against your decision records | `architect-rig` |

## When to read these

**You want to know why a layer exists.** [W4](../progression/W4-tour-the-factory.md) tours the installed factory and says what each piece does. These pages say why it was added and what the factory was missing without it, which is the more useful thing when you are designing your own.

**You are building a pack of your own.** Each page is a worked example of the same move: notice a gap, write the smallest pack that closes it, install it as a layer rather than an edit. That is the shape every Day 2 option also takes.

**Something in the base factory is not behaving.** The page that built a piece is usually the fastest explanation of how it is supposed to behave.

## What they assume

They were written as a sequence, each one starting from the end of the last, and they still read that way. If you work through them, start at the top. They also predate the base pack, so where a page says to copy a pack into `packs/` and import it, the base factory has already done that for you — read those sections for the reasoning rather than running them against a factory that is already built.

The three governance rules in [the review-loop page](./02-first-review-loop.md) are worth reading whatever else you skip. They are the vocabulary for talking about a factory with someone who has to approve it.
