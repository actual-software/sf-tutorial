# W-8 · Sharing Your Factory

« [previous: L-5 Implement a Feature](./09-implement-a-feature.md) | [next: modules index](../modules/README.md) »

**Workshop · Thursday 4:30–5:00 · 30 minutes · closing block**

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [What actually travels](#what-actually-travels)
- [Four audiences, four different jobs](#four-audiences-four-different-jobs)
- [What has to be scrubbed](#what-has-to-be-scrubbed)
- [What a second person needs to run it](#what-a-second-person-needs-to-run-it)
- [Deliverable](#deliverable)
- [What's next](#whats-next)

## Objective

Leave with a decision about who gets your factory and a short list of what you have to do before they can run it.

## Prereqs

Two days of it. Nothing to install.

## What actually travels

The instinct is to hand someone your factory directory. It is the wrong unit, and knowing why makes every other decision in this block easy.

Your working setup is four things with very different portability:

| Layer | Travels? | Why |
| --- | --- | --- |
| **Packs** — agents, formulas, orders | Yes, cleanly | Text, version-controlled, no machine state. This is the factory. |
| **City config** — `city.toml`, imports | Mostly | Portable except the absolute paths, which are per-machine by design. |
| **Rig registration** — which repos, where | No | Points at paths on your disk and repos the recipient may not have. |
| **Runtime state** — the bead store, sessions, logs | No, and you would not want it to | Your work queue and your history. Someone else's factory has its own. |

So the answer to "how do I share this" is almost always: **share the packs, document the config, and let them register their own rigs.** The thing you built over two days is a directory of text files, and that is good news.

The corollary matters just as much. If your factory only works because of something on your machine that is not in a pack, that is not a sharing problem, it is a reproducibility problem, and it will bite you on a new laptop long before it bites a colleague.

## Four audiences, four different jobs

"Sharing" means four quite different tasks depending on who is receiving it.

**Yourself, later.** The one everybody skips and everybody needs. The failure is not losing files, it is opening a formula in six weeks and not knowing why a step exists. The fix is small: a `README.md` next to your packs saying what each one is for and what it assumes. Do this one even if you do nothing else in this block.

**Your team.** Now reproducibility is the whole job. Pin your toolchain the way [`deps.sh`](../bootstrap/deps.sh) does, write down the prerequisites, and have exactly one person other than you run it from scratch on a clean machine before you tell everyone it works. That last step is not optional, and this curriculum learned it the hard way: an earlier version was authored against an older `gc` and a newer one rejected config that used to be accepted, which broke the setup chain partway through a live session.

**Your organisation, as a proposal.** The audience is people deciding whether to allow this, and they are not asking whether it works. They are asking which decisions a model is allowed to make. Everything from [W-4](./02-first-review-loop.md) is the answer, in their language: an unresolved blocking check prevents work from being marked ready, consequential decisions have a deterministic gate or a named human, and the system fails visibly when evidence is missing. Show the gate that rejected something, not the pull request that merged.

**Publicly.** Highest scrub cost, and the one where a mistake is permanent. See below.

## What has to be scrubbed

Work through this before anything leaves your control. The first two are obvious and the last three are the ones that actually get people.

- **Credentials.** Tokens, keys, `.env` files. Check the history, not just the working tree; a rotated key that is still in a commit is still a leak.
- **Internal URLs and hostnames.** Dashboards, staging endpoints, ticket links, anything behind your VPN.
- **Your backlog.** The bead store is not part of a pack, but exported issue files sometimes come along. Your beads describe unshipped work in your own words.
- **Prompts that quote internal context.** This is the sneaky one. Agent prompts get good precisely by absorbing specifics — a customer name, an incident, an architectural embarrassment, a colleague's judgement about a subsystem. Read every prompt you wrote in the last two days as though a competitor were reading it, because a prompt is documentation you forgot you were writing.
- **Names and identifiers.** `CODEOWNERS`, reviewer names, anything naming a person who did not agree to be named. And check the repository's own visibility before you decide any of this: the calculus for a public repo is not the calculus for a private one, and confirming which you are pushing to takes five seconds.

A blunt rule that resolves most cases: **if you would not put it in a public README, it does not belong in a prompt template you are about to share.**

## What a second person needs to run it

Four things, and you can write them in ten minutes:

1. **Prerequisites, pinned.** The tools and the exact versions. [`deps.sh`](../bootstrap/deps.sh) is the shape to copy: one script, checksummed downloads, versions in one place.
2. **A pass-or-fail check.** [`preflight.sh`](../bootstrap/preflight.sh) is the shape. The point is a single line at the end that says whether they are ready, so their first failure is not at step nine.
3. **The install order.** Which packs, at which scope, in what order. Anyone who has installed a pack at city scope that needed rig scope knows why this line exists.
4. **What it does and does not do.** The gates you built, and the decisions you deliberately kept a human in. Under-promising here is what makes the thing credible.

That list is also a decent audit of your own setup. Anything you cannot write down is something that only works because you know a thing you have not recorded.

## Deliverable

Two sentences, written down before you leave:

> I am sharing my factory with **\<yourself later | my team | my org | publicly\>**, and before that can happen I need to **\<the one thing at the top of the scrub list\>**.

If you have five spare minutes, write the `README.md` for the "yourself, later" case. It is the audience you are guaranteed to have.

## What's next

That is the two days. You have a factory pointed at your own project, with gates you can defend, channels you chose deliberately, and a written list of what to build next.

The capability map from [L-1](./07-plan-your-factory.md) is the thing to keep. It has rows on it you did not get to, and it is the only artifact here that knows what your factory cannot do yet.

The [`hardening/`](../README.md#hardening-exercises-optional-layer-on-as-you-like) exercises you did not pick in [L-3](../hardening/03-architecture-best-practices-loop.md) are the obvious next session, and both run fine on your own rig now.

« [previous: L-5 Implement a Feature](./09-implement-a-feature.md) | [next: modules index](../modules/README.md) »
