<h1><img src="images/software_factory_intensive_title.svg" alt="Software Factory Intensive"></h1>

<p>
  Event by <a href="https://aitinkerers.org/"><img src="images/ai_tinkerers.png" alt="AI Tinkerers" height="28" valign="middle"></a>
  &nbsp;|&nbsp;
  Hosted by <a href="https://www.actual.ai/"><img src="images/actual_ai.png" alt="Actual AI" height="28" valign="middle"></a>
</p>

This is a multi-step software factory intensive, built on [Gas City](https://github.com/gastownhall/gascity) to:

1. Provide a fast path to the simplest possible factory.
1. Demonstrate key components of a software factory.
1. Teach you how to customize those components so that you can create the agents and workflows you need to power your own software factory.

You'll start with out-of-the-box examples that ships with Gas City and two reference implementation agents from Gas Town, `mol-polecat-work` and `mol-refinery-patrol`. And you'll evolve a multi-agent workflow. You'll start with a simple **implement -> review** workflow. Then as the tutorials progress you'll layer on:

- GitHub pull requests
- Opinionated quality gates
- Specialize reviewer agents
- An architecture-best-practices loop
- A multi-model `code-review-loop`
- Etc.

## Community & Support

Stuck on a step, want to share what you've built, or looking to collaborate with other participants? Join the [Actual AI User Community Slack](https://join.slack.com/t/actualaiusercommunity/shared_invite/zt-3vibgzapf-ywx0Db29mZ4lhtQJGzZfGQ)! Here you can share what you've built, ask questions, and get help from other members of the community.

## What you'll build

By the end of the Progression, you'll have:

- A Gas City factory named `factory1`
- An example project or "rig" named `ascii-art` pushed to your own GitHub repo
- Gas City **packs** with **formulas** and **agents** that wire the `ascii-art` project to your workflows

## Factory1

**Factory1** is totally decoupled from the ASCII Art example project. If you're happy with its functionality at the end of these tutorials, you can start using it with your own projects immediately. If not, you'll have what you need to customize it further, and then you can start using it. You don't need to create a different factory to get started with Gas City.  

## ASCII Art

The example project is intentionally simple. The point is to learn the workflows.

Even though you're learning how to build a software factory, our examples simply generate text files, specifically ASCII Art ([like this](https://www.asciiart.eu/gallery)) for letters A-Z and numbers 1-100, along with little rhymes in each. 

All the same principles and processes apply. In your projects, your technical requirements will be related to your technologies stack rather than how many characters are allowed in each file, and your design system will focus on your brand and user experience rather than styling of markdown files. These details are project- or rig- specific. They do not live in the factory.    

## Prerequisites

Tools and versions:

- `gc` 1.0+
- `bd` 1.0+
- `gh` 2.x (authenticated: `gh auth status`)
- `git`
- macOS or Linux with `tmux` available

GitHub:

- One **fresh GitHub repo** for the rig — your own org or a sandbox account. The rig will push to this repo and branch protection will be applied to it.

## Tutorial structure

Three ways through this repo. The pages are the same; what differs is the order and the pacing.

### Two-day intensive (start here if you are at the event)

[**modules/**](./modules/README.md) is the taught path: thirteen blocks across two days, each one owning a time window and ending in a deliverable. Wednesday runs on one shared factory and one shared example; Thursday runs on your own project. The module pages sequence the progression and hardening pages below, and add the six sessions those pages never covered.

Start at [W-1 Preflight Setup](./progression/00.0-preflight.md), then follow the [module index](./modules/README.md).

### Basic Progression (sequential, do these in order)

Each step unlocks the next. Every page is self-contained: prereqs, walkthrough with copy-pasteable commands, verification block, troubleshooting, and a "what's next" link.

1. [Preflight: check your toolchain](./progression/00.0-preflight.md) — `deps.sh` plus a single pass-or-fail line before you build anything
1. [Setup: Create a Gas City named factory1](./progression/00.1-setup-foundation.md) — `gc init`, import a setup pack (based on the `gastown` reference pack), configure `city.toml`
2. [Setup: Add ASCII Art rig](./progression/00.2-setup-foundation.md) — `gc rig add`, push to GitHub, create 138 beads
3. [Setup: env vars](./progression/00.3-setup-foundation.md) — handy variables for easier copy-and-paste-ing
4. [Basic flow (OOTB)](./progression/01-basic-flow.md) — one agent claims a bead and implements (`mol-polecat-work`) + another reviews (`mol-refinery-patrol`) with no extras
5. [First review loop](./progression/02-first-review-loop.md) — extend the refinery patrol with a required round of feedback before any bead becomes a PR
6. [Branch protection](./progression/03-branch-protection.md) — only approved humans merge to `main`
7. [Architect agent](./progression/04-adr-reviewer.md) — add an architecture-aware reviewer between the polecat and the refinery
8. [Bead gate checks](./progression/05.1-bead-gate-checks.md) — add a project-manager agent at the front of the factory
9. [Bead gate checks — Grill Me](./progression/05.2-bead-gate-checks.md) — refine beads at the source with a local Grill-Me skill

### Hardening Exercises (optional, layer on as you like)

These are independent follow-ons. Pick the ones that interest you; they don't have to be done in order.

1. [Bead-creation formula extensions](./hardening/01-bead-creation-formula-extensions.md) — auto-link/create design, testing, and documentation references
2. [Specialize reviewers per domain](./hardening/02-specialize-reviewers-per-domain.md) — split the single reviewer into ADR, design, testing, and docs reviewers
3. [Architecture best practices loop](./hardening/03-architecture-best-practices-loop.md) — per-principle scoring with an append-only audit trail
4. [Strengthen review system](./hardening/04-strengthen-review-system.md) — multi-vendor reviewers, a synthesizer, and an iterate loop

## How to use this repo

1. Clone this repo and `cd` into it.
2. Read this README end to end (you're nearly done).
3. Run [`progression/00.0-preflight.md`](./progression/00.0-preflight.md) and get a `PREFLIGHT: PASS`.
4. Open [`progression/00.1-setup-foundation.md`](./progression/00.1-setup-foundation.md) and work through it.
5. Each page ends with a "what's next" link. Follow it.
6. After the **Basic Progression**, browse the **Hardening Exercises** and pick what's useful.

At the two-day intensive, follow the [module index](./modules/README.md) instead — it routes through these same pages in the order the schedule uses.

Every page is designed to be copy-paste-runnable. Commands are exact. When a page introduces a new artifact (a formula, an agent definition, a script), the artifact lives under [`artifacts/`](./artifacts/) and the page tells you exactly where to put it.

---

Ready? Head to [progression/00.0-preflight.md](./progression/00.0-preflight.md).
