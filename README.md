<h1><img src="images/software_factory_intensive_title.svg" alt="Software Factory Intensive"></h1>

<p>
  Event by <a href="https://aitinkerers.org/"><img src="images/ai_tinkerers.png" alt="AI Tinkerers" height="28" valign="middle"></a>
  &nbsp;|&nbsp;
  Hosted by <a href="https://www.actual.ai/"><img src="images/actual_ai.png" alt="Actual AI" height="28" valign="middle"></a>
</p>

## Table of Contents

- [Overview](#overview)
- [About Gas City](#about-gas-city)
- [Community & Support](#community--support)
- [Prerequisites](#prerequisites)
- [Curriculum Structure](#curriculum-structure)
  - [Day 1: Run and Explore Standard Software Factory](#day-1-run-and-explore-standard-software-factory)
  - [Day 2: Build Your Own Software Factory](#day-2-build-your-own-software-factory)

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

## Curriculum Structure

### Day 1: Run and Explore Standard Software Factory

| Session | Type | Duration | Title | Session Pages |
|----|------|----------|-------|-------------|
| W1 | Workshop | 60 min | Preflight Setup | [`Preflight Setup`](./progression/00.0-preflight.md) |
| W2 | Workshop | 60 min | Run a Software Factory | [`Create a Factory`](./progression/00.1-setup-foundation.md), [`Add ASCII Art Rig`](./progression/00.2-setup-foundation.md), [`Env Vars for Fresh Shells`](./progression/00.3-setup-foundation.md), [`Basic Flow`](./progression/01-basic-flow.md) |
| W3 | Workshop | 60 min | Review Loops | [`First Review Loop`](./progression/02-first-review-loop.md), [`Branch Protection`](./progression/03-branch-protection.md), [`Architect Agent`](./progression/04-adr-reviewer.md) |
| W4 | Workshop | 60 min | Requirement Gates | [`Bead Gate Checks`](./progression/05.1-bead-gate-checks.md), [`Bead Gate Checks — Grill Me`](./progression/05.2-bead-gate-checks.md), [`Bead Creation Formula Extensions`](./hardening/01-bead-creation-formula-extensions.md) |
| W5 | Workshop | 30 min | Coordination Channels | [`Coordination Channels`](./progression/06-coordination-channels.md) |
| L1 | Lab | 60 min | Plan Your Factory | [`Plan Your Factory`](./progression/07-plan-your-factory.md) |

#### Day 2: Build Your Own Software Factory

| Session | Type | Duration | Title | Session Pages |
|----|------|----------|-------|-------------|
| W6 | Workshop | 45 min | The Mayor and Workflows | [`The Mayor and Workflows`](./progression/08-mayor-and-workflows.md) |
| L2 | Lab | 45 min | Retargeting the Rig | [`Specialized Domain Reviewers`](./hardening/02-specialize-reviewers-per-domain.md) |
| L3 | Lab | 90 min | Hardening | [`Architecture Best-Practices Loop`](./hardening/03-architecture-best-practices-loop.md), [`Strengthen the Review System`](./hardening/04-strengthen-review-system.md) |
| L4 | Lab | 45 min | Self-Improvement Loop | [`Self-Improvement Loop`](./hardening/05-self-improvement-loop.md) |
| L5 | Lab | 90 min | Implement a Feature | [`Implement a Feature`](./progression/09-implement-a-feature.md) |
| W7 | Workshop | 30 min | Sharing Your Factory | [`Sharing Your Factory`](./progression/10-sharing-your-factory.md) |

---

Ready? Head to [Preflight Setup](./progression/00.0-preflight.md).
