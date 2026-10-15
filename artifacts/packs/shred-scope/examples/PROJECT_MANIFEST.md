# Project manifest

What this project is, written for an agent that has never seen it. This copy is filled in for the tutorial's `ascii-art` rig, and its last section is a small scope for the `shred-scope` skill to cut into beads.

## What this project does

`ascii-art` is the tutorial's reference project: a flat folder of Markdown files, one per character, each holding a small piece of ASCII art and a two-line rhyme. A software factory builds it one bead at a time. The people reading it are workshop participants watching that factory work, so its rules are simple and nothing in it is load-bearing.

## Stack

| Layer | Choice | Notes |
| --- | --- | --- |
| Language | Markdown | One file per character under `ascii/` |
| Framework | None | |
| Data store | The git repository | The files are the product |
| Build / package manager | None | Nothing compiles or installs |
| Deploy target | GitHub | `main` is the published state |

## How to run the tests

There's no test suite. Each rule in the ASCII decision record is a one-line shell check, and these three are the ones a reviewer runs on a changed file. None of them gates a merge yet.

````bash
grep -c '^# ' ascii/<file>.md                                                        # prints 1
awk '/^```text$/{f=1;next} /^```$/{f=0} f' ascii/<file>.md | awk 'length>20 || NR>8'  # prints nothing
awk '/^```$/{f=1;next} f && NF' ascii/<file>.md | wc -l                              # prints 2
````

## What must never break

- Every file in `ascii/` follows `docs/decision-records/0001.ADR.ASCII.md`: one H1 naming the character, one `text` code block, then a two-line rhyme and nothing else.
- Art stays inside 8 lines by 20 columns, in printable ASCII, with no tabs and no trailing spaces.
- Filenames match `^([a-z]|[1-9][0-9]?|100)\.md$`, and nothing else lives in `ascii/`.

## Conventions, and where they are written down

| Convention | Where it lives |
| --- | --- |
| Code style | `docs/decision-records/0001.ADR.ASCII.md` |
| Commit messages | Not written down. The polecat writes them. |
| Branch naming | Not written down. The polecat names its branches. |
| Architecture decisions | `docs/decision-records/` |

The two rows that say *not written down* are capability-map rows: a reviewer with nothing to cite produces opinions rather than verdicts.

## What a change normally touches

| Area | Path | Needs a human |
| --- | --- | --- |
| Art | `ascii/<character>.md` | No |
| Galleries | `gallery/` | No |
| Decision records | `docs/decision-records/` | Yes |

## Scope

The next batch is the numbers 1 to 5, and one gallery page that shows them together.

- **The numbers.** `ascii/1.md` to `ascii/5.md`, one file per number, each following the decision record above.
- **The gallery.** `gallery/numbers-1-5.md` shows the five in order. Each number gets an H2 naming it, followed by its art copied verbatim from its file in `ascii/`. It's written after the other five, because it copies them.

Out of scope for this batch: numbers above 5, any letter, and any change to the decision records.
