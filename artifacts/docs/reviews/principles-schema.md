# Principles Review File Schema

## Purpose

For every work bead that runs `mol-principles-review`, an append-only
YAML file lives at `docs/reviews/principles.<bead-id>.yaml` recording
every score across every iteration. It is the source of truth for
`checks/aggregate-score.sh` and the audit trail operators inspect on
escalation.

## Row format

One principle, one reviewer, one iteration. Rows are appended only.

```yaml
- principle: TDD
  reviewer: ascii-art/reviewer
  score: 4
  findings: "Tests cover the happy path; missing edge case for empty input."
  timestamp: 2026-05-06T22:30:00Z
```

- `principle` — exact string from the 23-item list. Case-sensitive.
- `reviewer` — agent identity. Single-reviewer mode is
  `ascii-art/reviewer`; multi-vendor mode (see below) uses identities
  like `reviewer-codex`, `reviewer-claude`, `reviewer-gemini`.
- `score` — integer 0–5 inclusive.
- `findings` — 1–2 sentences. Long detail goes in `docs/reviews/principles/<bead-id>.<slug>.md`.
- `timestamp` — RFC 3339 UTC; no two rows may share the full
  `(principle, reviewer, timestamp)` tuple. Different reviewers MAY
  share a timestamp on the same principle.

## Aggregation rule

**Latest-row-wins per (principle, reviewer).** Group rows by the
`(principle, reviewer)` pair; take the most-recent `timestamp` in each
group. Then collapse per principle by averaging the latest score from
each reviewer that covered it. Then average across all 23 principles
and divide by 5:

```
latest[(principle, reviewer)]   = row with max(timestamp) in that group
per_principle[principle]        = mean(latest[(principle, *)].score)
aggregate                       = mean(per_principle[p] for p in 23) / 5
```

A principle with no rows from any reviewer counts as 0 (treated as
"missing"); PASS cannot fire until every principle has at least one
row from at least one reviewer.

In single-reviewer mode the rule reduces to the original
"latest-per-principle" form: one reviewer means one latest row per
principle, and the per-principle mean equals that single score.

## Exit conditions

- **PASS** (rc 0) — `aggregate >= target_score` AND every latest score
  `>= min_per_principle`. Formula stamps `metadata.principles_review_passed=true`.
- **CONTINUE** (rc 1) — thresholds not met, iterations remain. Formula
  re-pours with `iteration` incremented.
- **ESCALATE (cap)** — continue conditions hold but `max_iterations`
  was reached. Operator mailed.
- **ESCALATE (malformed)** (rc 2) — bad YAML, out-of-range score,
  duplicate timestamp, or any unparseable row. Operator mailed; no
  auto-repair.

## Validation

A row is malformed if: the file does not parse as YAML, a required
field is missing, `score` is non-integer or outside 0–5, two rows
share the full `(principle, reviewer, timestamp)` tuple, or
`principle` is not one of the 23 canonical names.

## Example

```yaml
# Principles review for ascii-art-42 - append-only
# Schema: docs/reviews/principles-schema.md
rows:
  - {principle: TDD,  reviewer: ascii-art/reviewer, score: 2,
     findings: "No tests on the new renderer module.",
     timestamp: 2026-05-06T22:30:00Z}
  - {principle: KISS, reviewer: ascii-art/reviewer, score: 5,
     findings: "Direct implementation; no incidental complexity.",
     timestamp: 2026-05-06T22:30:05Z}
  - {principle: TDD,  reviewer: ascii-art/reviewer, score: 4,
     findings: "Tests added; one edge case still uncovered.",
     timestamp: 2026-05-06T23:14:11Z}
```

TDD scored twice across two iterations; the aggregator counts only the
later row (`score: 4`). The other 21 principles still need rows before PASS is possible.

## Multi-vendor extension

When the formula runs with a non-empty `vendors` list (e.g.,
`reviewer-codex,reviewer-claude,reviewer-gemini`), every vendor writes
its own row per principle. The row format is unchanged; only the
`reviewer` value varies. Multiple rows can share the same `principle`
on the same iteration -- they are distinguished by `reviewer` and
`timestamp`.

Three vendors x 23 principles produces up to 69 latest rows per
iteration, which the aggregator collapses to 23 per-principle means:

```yaml
- {principle: TDD, reviewer: reviewer-codex,  score: 3, findings: "...", timestamp: 2026-05-06T22:30:00Z}
- {principle: TDD, reviewer: reviewer-claude, score: 4, findings: "...", timestamp: 2026-05-06T22:30:01Z}
- {principle: TDD, reviewer: reviewer-gemini, score: 5, findings: "...", timestamp: 2026-05-06T22:30:02Z}
```

`per_principle["TDD"] = mean(3, 4, 5) = 4.0`. Across all 23 principles,
divide the overall mean by 5 to get `aggregate`. If only some vendors
covered a principle, the per-principle mean is over those vendors;
zero-coverage still counts as 0.
