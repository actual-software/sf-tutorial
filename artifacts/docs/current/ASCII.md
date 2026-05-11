# ASCII Files: Current Technical Reference

## Purpose

This is the current technical reference for ASCII files in the `ascii-art`
rig (city `factory1`). The decision rationale lives in
`../decision-records/0001.ADR.ASCII.md`; if the ADR changes, this doc must
be updated to match.

## File layout

All ASCII art files live in `ascii/` at the repository root, flat. No
subdirectories are permitted. Filenames follow this pattern:

```
^(?:[a-z]|[1-9][0-9]?|100)\.md$
```

That is: a single lowercase letter `a`–`z`, or a decimal number from `1` to
`100` with no leading zeros, followed by `.md`. Examples: `a.md`, `z.md`,
`1.md`, `42.md`, `100.md`. Anything else in `ascii/` fails validation.

## File template

Every conforming file contains exactly three elements, in this order: one H1,
one fenced code block tagged `text`, and one 2-line rhyming couplet of plain
prose. Nothing else — no extra headings, lists, blockquotes, images, links,
HTML, or trailing content.

````
# <CHAR>

```text
<ascii art, up to 40 lines tall, up to 40 columns wide>
```

<rhyme line one>
<rhyme line two>
````

`<CHAR>` is the character itself: uppercased for letters (`# A`, `# Z`),
bare digits for numbers (`# 42`).

## Example: `a.md`

A complete, conforming file for the letter `a`:

````markdown
# A

```text
   /\
  /  \
 / /\ \
/_/  \_\
```

A peak of slashes, narrow at the crown,
two legs that brace it firmly to the ground.
````

The art is 4 lines tall and 8 columns wide — well inside the 8x20 box. The
H1 is `# A`, and the rhyme sits directly under the closing fence.

## Constraints quick reference

| Area       | Rule                                                           |
|------------|----------------------------------------------------------------|
| Location   | `ascii/` at repo root; no subdirectories                       |
| Naming     | `<a-z>.md` or `<1-100>.md`; no leading zeros                   |
| H1         | Exactly one; text is the character (letters uppercased)        |
| Code block | Exactly one fenced block, language `text`                      |
| Art height | Maximum 40 lines (excluding fences)                             |
| Art width  | Maximum 40 columns (longest line, in characters)               |
| Charset    | ASCII printable only (`0x20`–`0x7E`); no tabs, no trailing ws  |
| Rhyme      | Exactly 2 plain-prose lines that rhyme; no markdown formatting |
| Other      | No extra headings, lists, blockquotes, images, links, or HTML  |

## Compliance checks

Each rule is mechanically checkable. The CI workflow at
`../../github/workflows/ascii-compliance.yml` (authored in Hardening 1)
runs the canonical lint. Quick local checks:

- Unexpected filenames: `ls ascii/ | grep -Ev '^([a-z]|[1-9][0-9]?|100)\.md$'`
- H1 count (must be 1): `grep -c '^# ' ascii/a.md`
- Lines wider than 40 columns: `awk 'length>40' ascii/a.md`
- Non-ASCII bytes: `LC_ALL=C grep -nP '[^\x20-\x7E]' ascii/a.md`
- Trailing whitespace: `grep -nE ' +$' ascii/a.md`

The Step 4 reviewer agent runs the same checks rule-by-rule against the PR
diff and posts an approve-or-reject comment citing the rule applied.

## Common mistakes

1. **Wrong fence language.** Using ` ```ascii ` or no language at all. Fix:
   the opening fence must be exactly ` ```text `.
2. **Heading above the rhyme.** Adding `## Rhyme` or similar before the
   couplet. Fix: delete the heading; the two prose lines sit directly under
   the closing fence.
3. **Art exceeds the canvas.** The longest line is 21+ columns or there are
   41+ lines of art. Fix: redraw inside the 40x40 box; counting columns
   includes leading spaces.
4. **Tabs or smart quotes.** Editors silently insert tabs or `"`/`"`
   characters that fall outside `0x20`–`0x7E`. Fix: convert tabs to spaces
   and replace any non-ASCII punctuation.
5. **Filename drift.** Files like `A.md`, `01.md`, or `letter-a.md`. Fix:
   rename to lowercase letter or unpadded number per the regex above.
