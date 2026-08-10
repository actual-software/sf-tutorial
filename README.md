<h1><img src="images/software_factory_intensive_title.svg" alt="Software Factory Intensive"></h1>

<p>
  Event by <a href="https://aitinkerers.org/"><img src="images/ai_tinkerers.png" alt="AI Tinkerers" height="28" valign="middle"></a>
  &nbsp;|&nbsp;
  Hosted by <a href="https://www.actual.ai/"><img src="images/actual_ai.png" alt="Actual AI" height="28" valign="middle"></a>
</p>

## Table of Contents

- [Overview](#overview)
- [Before You Arrive](#before-you-arrive)
- [Directory Structure](#directory-structure)
- [Installation](#installation)
- [Day-to-day usage](#day-to-day-usage)
- [Going deeper](#going-deeper)

## Overview

This is a multi-step software factory intensive to give participants tools and principles to configure complete software factories for their use case. Participants will learn how to think about the dimensions of configurations for software factories and how to elevate their software development infrastructure above individual coding agents.

You'll start with out-of-the-box examples that ship with Gas City and two reference implementation agents from Gas Town, `mol-polecat-work` and `mol-refinery-patrol`. And you'll evolve a multi-agent workflow. You'll start with a simple **implement -> review** workflow. Then as the tutorials progress you'll layer on:

- GitHub pull requests
- Opinionated quality gates
- Specialize reviewer agents
- An architecture-best-practices loop
- A multi-model `code-review-loop`
- Etc.

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

## Tutorial structure

### Basic Progression (sequential, do these in order)

Each step unlocks the next. Every page is self-contained: prereqs, walkthrough with copy-pasteable commands, verification block, and troubleshooting. Work from the list below rather than the « previous | next » footer at the bottom of each page, which runs the two-day event order instead.

1. [Preflight: check your toolchain](./progression/00.0-preflight.md) — `deps.sh` plus a single pass-or-fail line before you build anything, on your laptop or a cloud box
2. [What is a software factory?](./progression/00.05-what-is-a-software-factory.md) — the vocabulary, and how it maps onto the demo repo; prose only, nothing to install
3. [Setup: Create a Gas City named factory1](./progression/00.1-setup-foundation.md) — `gc init`, import a setup pack (based on the `gastown` reference pack), configure `city.toml`
4. [Setup: Add ASCII Art rig](./progression/00.2-setup-foundation.md) — `gc rig add`, push to GitHub, create 138 beads
5. [Setup: env vars](./progression/00.3-setup-foundation.md) — handy variables for easier copy-and-paste-ing
6. [Basic flow (OOTB)](./progression/01-basic-flow.md) — one agent claims a bead and implements (`mol-polecat-work`) + another reviews (`mol-refinery-patrol`) with no extras
7. [First review loop](./progression/02-first-review-loop.md) — extend the refinery patrol with a required round of feedback before any bead becomes a PR
8. [Branch protection](./progression/03-branch-protection.md) — only approved humans merge to `main`
9. [Architect agent](./progression/04-adr-reviewer.md) — add an architecture-aware reviewer between the polecat and the refinery
10. [Bead gate checks](./progression/05.1-bead-gate-checks.md) — add a project-manager agent at the front of the factory
11. [Bead gate checks — Grill Me](./progression/05.2-bead-gate-checks.md) — refine beads at the source with a local Grill-Me skill
12. [Coordination channels](./progression/06-coordination-channels.md) — mail, wakes, nudges and attach, plus a fallback for every handoff
13. [Plan your factory](./progression/07-plan-your-factory.md) — register your own rig, write a project manifest, and produce a capability map
14. [The mayor and workflows](./progression/08-mayor-and-workflows.md) — formulas and orders, and one workflow walked end to end
15. [Implement a feature](./progression/09-implement-a-feature.md) — a directed build against the capability map from the planning page
16. [Sharing your factory](./progression/10-sharing-your-factory.md) — what you publish, what stays private, and what gets scrubbed first

### Hardening Exercises (optional, layer on as you like)

These are independent follow-ons. Pick the ones that interest you; they don't have to be done in order. Open them from this list rather than by footer, which sends you from the first exercise back into the progression, where the two-day schedule teaches it.

1. [Bead-creation formula extensions](./hardening/01-bead-creation-formula-extensions.md) — auto-link/create design, testing, and documentation references
2. [Specialize reviewers per domain](./hardening/02-specialize-reviewers-per-domain.md) — split the single reviewer into ADR, design, testing, and docs reviewers
3. [Architecture best practices loop](./hardening/03-architecture-best-practices-loop.md) — per-principle scoring with an append-only audit trail
4. [Strengthen review system](./hardening/04-strengthen-review-system.md) — multi-vendor reviewers, a synthesizer, and an iterate loop
5. [Self-improvement loop](./hardening/05-self-improvement-loop.md) — the factory proposes a change to its own configuration, behind a gate

---

Ready? Head to [progression/00.0-preflight.md](./progression/00.0-preflight.md).
