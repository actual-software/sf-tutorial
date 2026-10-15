# ADR 0000: Record architecture decisions

- Status: Accepted
- Date: 2026-10-14

## Context

Fired Up Pizza is built by a Gas City software factory. Polecats implement beads in parallel, and an architect agent reviews every branch before the refinery merges it. The architect treats `docs/decision-records/*.md` as binding rules and `docs/current/**/*.md` as a description of what exists today.

`docs/PROJECT_MANIFEST.md` proposed `docs/adr/` for decision records. This rig's architect reads `docs/decision-records/`, so the records live there.

## Decision

1. Decision records live in `docs/decision-records/NNNN-kebab-case-title.md`, numbered sequentially from 0000. Each one has a Status (`Accepted` or `Superseded by NNNN`), a date, its context, numbered rules, and consequences.
2. Accepted records are binding on all code in this repository. A change that conflicts with a record must add a new record that supersedes it, and mark the old one `Superseded by NNNN` in the same branch. Never quietly edit the rules of an accepted record. Clarifications that do not change meaning are fine.
3. Rules are numbered so reviews can cite them precisely, e.g. "ADR 0004 rule 2".
4. `docs/current/` describes the system as it is: module map, implementation state, how to run it. Keep it accurate when the structure changes. It is not a source of rules.
5. When a record and `docs/PROJECT_MANIFEST.md` disagree, the record wins and names the manifest section it refines. The manifest stays as the product input.

## Consequences

- Every bead can rely on the same decisions without re-litigating them, and the architect has a fixed checklist to review against.
- Changing an architectural decision is a visible, reviewable act: a new ADR in the same branch as the code that needs it.
