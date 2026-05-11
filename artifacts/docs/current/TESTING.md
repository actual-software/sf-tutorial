# ASCII Compliance Testing: Current Reference

## Purpose

This is the current testing reference for the `ascii-art` rig. The decision
rationale lives in `../decision-records/0002.ADR.TESTING.md`. The 6 CI
checks below mirror the rules in `../decision-records/0001.ADR.ASCII.md`.
If those ADRs change, this doc and the CI workflow at
`.github/workflows/ascii-compliance.yml` update in lockstep.

## The 6 checks

Each pull request that touches `ascii/**` runs all six. Any single failure
fails the workflow.

| # | Check                       | Rule (one-liner)                                                                  | Local reproduction                                                              |
|---|-----------------------------|-----------------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| 1 | Filename regex              | Path matches `^ascii/(?:[a-z]\|[1-9][0-9]?\|100)\.md$`                             | `ls ascii/ \| grep -Ev '^([a-z]\|[1-9][0-9]?\|100)\.md$'`                       |
| 2 | File location               | Sits directly in `ascii/` at repo root; no subdirectories                         | `find ascii -mindepth 2 -type f`                                                |
| 3 | H1 with character title     | Exactly one H1; letters match `^# [A-Z]$`, numbers match `^# [1-9][0-9]?$\|^# 100$` | `grep -c '^# ' ascii/a.md` then `grep -E '^# ([A-Z]\|[1-9][0-9]?\|100)$' ascii/a.md` |
| 4 | Single fenced `text` block  | Exactly one fenced code block opened with ```` ```text ```` and closed with ```` ``` ```` | `grep -c '^```' ascii/a.md` (must print `2`)                                    |
| 5 | ASCII art bounds            | Inside the fence: at most 8 lines, at most 20 columns, printable ASCII only, no tabs, no trailing whitespace | `awk '/^```text$/{f=1;next} /^```$/{f=0} f' ascii/a.md \| awk 'length>20 \|\| /\t/ \|\| / +$/'` |
| 6 | Two-line rhyme couplet      | Below the closing fence: exactly two non-empty lines and nothing else             | `awk '/^```$/{f=1;next} f && NF' ascii/a.md \| wc -l` (must print `2`)          |

The order matches ADR 0002 exactly. Do not reorder when triaging.

## Local validation script

Before pushing, run all 6 checks against a single file with the helper
script `scripts/check-ascii.sh`. It accepts one path under `ascii/` and
exits non-zero on the first failing rule, printing `FAIL: rule <n> — <reason>`.
On success it prints `PASS: <path>`.

What the script does, rule by rule:

1. Validates the basename against the filename regex.
2. Asserts the path is `ascii/<basename>` with no intermediate directories.
3. Counts H1 lines and matches the heading text against the per-type regex.
4. Counts fence lines (` ``` ` at column 0) — must be exactly 2 — and
   confirms the opening fence is ` ```text `.
5. Slices the lines between the fences and checks line count, max column
   width, printable-ASCII range (`0x20`–`0x7E`), absence of tabs, and
   absence of trailing whitespace.
6. Slices everything after the closing fence and confirms exactly two
   non-empty lines remain, with no headings, blockquotes, lists, links,
   HTML, or other markdown.

Sample invocation:

```bash
./scripts/check-ascii.sh ascii/a.md
# PASS: ascii/a.md

./scripts/check-ascii.sh ascii/a.md
# FAIL: rule 5 — art is 9 lines (max 8)
```

To check every file at once:

```bash
for f in ascii/*.md; do ./scripts/check-ascii.sh "$f" || exit 1; done
```

## CI behavior

The workflow at `.github/workflows/ascii-compliance.yml` runs the same six
checks in GitHub Actions. Concretely:

- **Trigger.** `pull_request` events whose changed paths match `ascii/**`.
- **Scope.** Only the files changed by the PR are validated. Existing files
  are not re-linted on unrelated PRs.
- **Status check.** The required-status-check name is the literal string
  `ci/ascii-compliance`. `branch-protection.sh` references this name; the
  two MUST stay in sync. Branch protection on `main` refuses merges whose
  `ci/ascii-compliance` job has not reported success.
- **Failure model.** All 6 checks run for every changed file. The workflow
  fails if any rule fails on any file. A single PR can surface multiple
  failures in one run.
- **Annotations (goal).** Each failing rule is emitted as a GitHub
  annotation pinned to the offending file and, where possible, the offending
  line. This is the workflow's UX target — surface failures inline on the
  PR diff so the author can fix without re-reading the ADR.

The reviewer agent (page 04) and the vendor-diverse reviewers added in
Hardening 4 both treat a green `ci/ascii-compliance` as a precondition;
they do not duplicate these mechanical checks.

## Common failures and fixes

| Failure message                                        | Fix                                                                                       |
|--------------------------------------------------------|-------------------------------------------------------------------------------------------|
| `filename A.md doesn't match regex`                    | Rename to lowercase: `git mv ascii/A.md ascii/a.md`. The regex requires `[a-z]`.          |
| `file ascii/letters/a.md not at ascii/ root`           | Move it up: `git mv ascii/letters/a.md ascii/a.md`. No subdirectories under `ascii/`.     |
| `H1 text "# Letter A" doesn't match ^# [A-Z]$`         | Change the heading to `# A`. Letters are uppercased and bare; numbers are bare digits.    |
| `fenced block uses lang bash not text`                 | Change ` ```bash ` to ` ```text ` on the opening fence. `text` is the only allowed lang.  |
| `art is 9 lines (max 8)`                               | Trim a line. ASCII art does not need to fill the box; 4–6 lines is common.                |
| `line 3 is 22 cols (max 20)`                           | Redraw inside the 20-column width. Leading spaces count.                                  |
| `found 3 non-empty lines after fence (expected 2)`     | Check for an accidental third rhyme line, signature, or blockquote. The couplet is exactly 2 lines. |
| `non-ASCII byte at line 5 col 12`                      | Editor inserted a smart quote or em-dash. Convert to plain ASCII (`'`, `-`).               |

## How to extend testing

This workflow is intentionally narrow: it enforces only the mechanical
rules in ADR 0001. Future stages add layers around it without replacing it.

- **Hardening 2** specializes reviewers per domain (design, testing, docs).
  Each domain may add its own check on top of `ci/ascii-compliance` — for
  example, a design reviewer that lints stroke style, or a docs reviewer
  that lints rhyme quality.
- **Hardening 4** introduces vendor-diverse reviewers plus a synthesizer.
  Their verdict can READ the CI signal and cite it, but it cannot BYPASS
  this CI: branch protection still requires `ci/ascii-compliance` green
  before merge, no matter what the synthesizer says.

When ADR 0001 or 0002 changes, update this doc and
`.github/workflows/ascii-compliance.yml` in the same PR. A drifted
workflow either blocks valid PRs or rubber-stamps invalid ones.
