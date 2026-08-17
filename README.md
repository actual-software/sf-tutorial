<h1><img src="images/software_factory_intensive_title.svg" alt="Software Factory Intensive"></h1>

<p>
  Hosted by <a href="https://www.actual.ai/"><img src="images/actual_ai.png" alt="Actual AI" height="28" valign="middle"></a>
</p>

## Table of Contents

- [Overview](#overview)
- [About Gas City](#about-gas-city)
- [Community & Support](#community--support)
- [Prerequisites](#prerequisites)
- [Curriculum Structure](#curriculum-structure)
  - [Day 1: run and explore a standard software factory](#day-1-run-and-explore-a-standard-software-factory)
  - [Day 2: build your own software factory](#day-2-build-your-own-software-factory)
  - [The six options](#the-six-options)
  - [The base factory](#the-base-factory)

## Overview

This is a multi-step software factory intensive to give participants tools and principles to configure complete software factories for their use case. Participants will learn how to think about the dimensions of configurations for software factories and how to elevate their software development infrastructure above individual coding agents.

The curriculum runs over two days. Day 1 stands up a working factory and takes it apart to see how it is made: packs, agents, formulas, orders, and the five ways agents coordinate. Day 2 points that machinery at a project of your own and extends it, from a menu of options you choose between rather than a fixed sequence.

You start from a base factory that already works, built on the out-of-the-box examples that ship with Gas City and two reference agents from Gas Town, `mol-polecat-work` and `mol-refinery-patrol`. What you layer on top is your choice: GitHub pull requests and quality gates are already in the base, and the options add specialized reviewer agents, an architecture-best-practices loop, a multi-model review, a gate at the front of the queue, and a loop that lets the factory propose changes to itself.

## About Gas City

[Gas City](https://github.com/gastownhall/gascity) is an open-source framework for running multi-agent systems. It abstracts the primitives of multi-agent coordination — agents, packs, rigs, beads, sessions, orders, routes — so that any multi-agent architecture can be expressed within the same framework rather than re-invented each time. Once you've learned the primitives, you can swap out the specific agent roles and build pipelines for code review, research, data processing, ops automation, etc.

For the authoritative definitions of every Gas City term (agent, pack, rig, bead, sling, order, route, formula, overlay, etc.), see the [Gas City glossary](https://github.com/gastownhall/gascity/blob/main/engdocs/architecture/glossary.md). Brief term map:

| Gas City Term | Analogous Term |
|---------------|----------------|
| bead   | Issue / ticket / task |
| convoy | Epic / batch |
| dog    | Daemon / cron worker |
| formula| Workflow / pipeline / recipe |
| mail   | Message / inbox item |
| order  | Cron job / scheduled task |
| pack   | Plugin / module / package |
| rig    | Workspace / repository |
| sling  | Job dispatch / enqueue |

## Community & Support

Stuck on a step, want to share what you've built, or looking to collaborate with other participants? Join the [Actual AI User Community Slack](https://join.slack.com/t/actualaiusercommunity/shared_invite/zt-3vibgzapf-ywx0Db29mZ4lhtQJGzZfGQ) to ask questions and get help from other participants.

## Prerequisites

### CLI Coding Agent Subscription (or API key)

You’ll need at least one coding agent subscription (or API key) to run the workshop. Having more than one gives you broader capabilities and redundancy.
  - **Recommended**: Claude Code Max (20x) or Codex Pro (20x)
  - **Minimum**: Claude Code Max or Codex Pro (standard tier)
  - **Alternatives**: Gemini CLI, OpenCode (compatibility not guaranteed)

### Actual Factory Demo

To prepare for the workshop, please install the [Actual Factory Demo](https://github.com/actual-software/actual-factory-demo) and follow the instructions to get it running. This proves your machine is ready to go and gives you a hands-on understanding of the basics of Gas City.

### Running on a cloud box (optional)

Doing the intensive on instructor-provided cloud boxes instead of your own laptop? Start at [`CLOUD_BOX_GUIDE.md`](./CLOUD_BOX_GUIDE.md). It takes the four values your instructor sends you through to a running factory, and it ends with the commands you'll use across the two days. No AWS account needed.

The CLI it drives, plus an optional agent skill, is documented in [`participant-box-cli/`](./participant-box-cli/README.md): deploy a factory pack, restart the service, read box state, and tunnel the dashboard to your browser.

## Curriculum Structure

Two days. Workshops (**W**) are taught; labs (**L**) are yours. Durations below are the general shape of a session rather than a fixed clock, since the curriculum runs at different events.

### Day 1: run and explore a standard software factory

| Session | Type | Duration | Title | Page |
|----|------|----------|-------|------|
| W1 | Workshop | 30 min | Vocabulary and Concepts | [`W1`](./progression/W1-vocabulary-and-concepts.md) |
| W2 | Workshop | 45 min | Cloud Box and Preflight | [`W2`](./progression/W2-cloud-box-and-preflight.md) |
| W3 | Workshop | 60 min | Run Your Factory | [`W3`](./progression/W3-run-your-factory.md) |
| W4 | Workshop | 60 min | Tour the Factory | [`W4`](./progression/W4-tour-the-factory.md) |
| W5 | Workshop | 30 min | Observability and Traceability | [`W5`](./progression/W5-observability.md) |
| L1 | Lab | 45 min | Point the Factory at Your Own Project | [`L1`](./progression/L1-plan-your-factory.md) |
| L2 | Lab | 30 min | Capability Map (starts) | [`L2`](./progression/L2-capability-map.md) |

### Day 2: build your own software factory

| Session | Type | Duration | Title | Page |
|----|------|----------|-------|------|
| L2 | Lab | 30 min | Capability Map (finishes) | [`L2`](./progression/L2-capability-map.md) |
| L3 | Lab | 45 min | First enhancement — one of the six options | [`L3-L5`](./progression/L3-L5-feature-labs.md) |
| W6 | Workshop | 60 min | Advanced Concepts | [`W6`](./progression/W6-advanced-concepts.md) |
| L4 | Lab | 60 min | Second enhancement | [`L3-L5`](./progression/L3-L5-feature-labs.md) |
| W7 | Workshop | 45 min | Sharing Your Factory | [`W7`](./progression/W7-sharing-your-factory.md) |
| L5 | Lab | 45 min | Third enhancement | [`L3-L5`](./progression/L3-L5-feature-labs.md) |

Both days also carry a Gas City speaker session and breaks, which are not pages.

### The six options

The three feature labs draw on the same menu. **L3** is one of these six. **L4** and **L5** are each either an option you have not used yet, or a feature of your own from your capability map.

| Option | Solves |
|---|---|
| [Bead gate checks](./hardening/06-bead-gate-checks.md) | Work reaches an implementer under-specified and it has to guess |
| [Bead creation formula extensions](./hardening/01-bead-creation-formula-extensions.md) | Beads arrive with no design, test or docs thinking attached |
| [Specialized domain reviewers](./hardening/02-specialize-reviewers-per-domain.md) | One reviewer judging everything reviews nothing well |
| [Architecture best-practices loop](./hardening/03-architecture-best-practices-loop.md) | Reviews are opinions rather than scores against named principles |
| [Strengthen the review system](./hardening/04-strengthen-review-system.md) | One model is one point of view, and it is confidently wrong sometimes |
| [Self-improvement loop](./hardening/05-self-improvement-loop.md) | The factory produces evidence about itself and nobody reads it |

**Every option installs on the base factory alone.** None requires another and none has to be taken in order, so pick on the basis of which problem you actually have.

### The base factory

W3 installs one pack, [`base-factory`](./artifacts/packs/base-factory/README.md), and gets a working multi-agent factory with an example of every Gas City primitive already running in it: formulas, an agent persona, orders, a rig, and mail. Day 2 extends it.

The four [appendix pages](./appendix/README.md) assemble that same factory by hand, step by step. They are off the taught path and worth reading when you want to know why a layer exists rather than what it does.

---

Ready? Start at [W1 Vocabulary and Concepts](./progression/W1-vocabulary-and-concepts.md).
