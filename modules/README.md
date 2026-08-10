# Modules

The taught path for the two-day intensive. Thirteen blocks, where `W-` is an instructor-led workshop and `L-` is a participant-led lab.

**This directory is a skeleton.** Every page below is a placeholder, and the content lands in the follow-on PR. Nothing under `progression/` or `hardening/` has been renamed, moved or deleted. This layer sits on top of those pages and points at them, which is why a module that merges four existing pages and a module that splits one across two blocks can both be expressed here without touching a single source file.

## Module map

Transcribed from the change gameplan's Name mapping table. Read this table against the file tree to check the PR.

| Block | Module | Draws on | Action |
| --- | --- | --- | --- |
| W-1 | [Preflight Setup](./W-1-preflight-setup.md) | [`bootstrap/deps.sh`](../bootstrap/deps.sh) | new page wrapping the script, plus a cloud branch |
| W-2 | [What is a Software Factory?](./W-2-what-is-a-software-factory.md) | *(nothing yet)* | new, prose only |
| W-3 | [Run a Software Factory](./W-3-run-a-software-factory.md) | [`00.1`](../progression/00.1-setup-foundation.md), [`00.2`](../progression/00.2-setup-foundation.md), [`00.3`](../progression/00.3-setup-foundation.md), [`01`](../progression/01-basic-flow.md) | unchanged, run at pace |
| W-4 | [Review Loops](./W-4-review-loops.md) | [`02`](../progression/02-first-review-loop.md), [`03`](../progression/03-branch-protection.md), [`04`](../progression/04-adr-reviewer.md) | reframed as one block |
| W-5 | [Requirement Gates](./W-5-requirement-gates.md) | [`05.1`](../progression/05.1-bead-gate-checks.md), [`hardening/01`](../hardening/01-bead-creation-formula-extensions.md) | `05.1` extended with a test-generation gate, `hardening/01` folded in |
| W-6 | [Coordination Channels](./W-6-coordination-channels.md) | *(nothing yet)* | new, and the largest authoring job |
| L-1 | [Plan Your Factory](./L-1-plan-your-factory.md) | [`00.2`](../progression/00.2-setup-foundation.md) | new page generalised off `ascii-art`, produces the capability map |
| W-7 | [The Mayor and Workflows](./W-7-mayor-and-workflows.md) | *(nothing yet)* | new |
| L-2 | [Retargeting the Rig](./L-2-retargeting-the-rig.md) | [`hardening/02`](../hardening/02-specialize-reviewers-per-domain.md) | retargeted off `ascii-art` |
| L-3 | [Hardening](./L-3-hardening.md) | [`hardening/03`](../hardening/03-architecture-best-practices-loop.md), [`hardening/04`](../hardening/04-strengthen-review-system.md) | participant picks one, chooser intro added |
| L-4 | [Self-improvement Loop](./L-4-self-improvement-loop.md) | [`hardening/03`](../hardening/03-architecture-best-practices-loop.md) | new framing over the existing scoring mechanics |
| L-5 | [Implement a Feature](./L-5-implement-a-feature.md) | *(nothing yet)* | new, and consumes L-1's capability map |
| W-8 | [Sharing Your Factory](./W-8-sharing-your-factory.md) | *(nothing yet)* | new, prose only |

Six blocks draw on nothing that exists yet and ship here as empty placeholders. Four merge several existing pages into one module, and two read from a page that also feeds another module. `progression/00.2-setup-foundation.md` feeds both W-3 and L-1, and `hardening/03-architecture-best-practices-loop.md` feeds both L-3 and L-4.

## What is deliberately not here

[`progression/05.2-bead-gate-checks.md`](../progression/05.2-bead-gate-checks.md) is retired from the taught path. It stays in the repo and works on its own, and its absence from the table above is intentional rather than an omission.

The [Basic Progression](../README.md) and the Hardening Exercises are unchanged. This directory sequences them and names the sessions they never covered.
