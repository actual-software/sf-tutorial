#!/usr/bin/env python3
"""Ask two questions of a bead, and answer them from the bead's own description.

    1. Is this bead security-shaped? Does its description name work that crosses
       a security boundary?
    2. If it is, does the description carry an audit matrix — a table saying,
       per resource, which rule covers it, which threat that rule defends
       against, and whether the coverage is complete?

A bead that answers yes to the first and no to the second is the one this pack
exists to catch. Implementation on that bead has to wait until someone writes
the matrix, because the alternative is discovering the missing rows in the
review thread after the code is written, which is where they are most expensive
to fix.

Three ways to run it:

    audit_matrix_check.py check <bead-id>   one bead; exit 1 when it needs a matrix
    audit_matrix_check.py scan              every open bead; always exit 0
    audit_matrix_check.py --self-test       planted cases; exit 1 on any miss

Exit 2 means the check could not run at all: bd was unreachable, or it answered
about a bead nobody asked about. Keep that separate from exit 1 in anything that
consumes this. A gate that reads "the tooling broke" as "this bead needs a
matrix" blocks work for a reason that is not true, and the message it writes
onto the bead sends whoever reads it looking for a security question that was
never there.

`check` is what the gate formula runs. `scan` is what the order runs. The
self-test is there because the beads on your board are not a test corpus for
this: a board with no security-shaped beads on it exercises none of the
interesting paths, so a clean scan and a broken detector look identical from
outside. Run the self-test after you edit either list below.
"""

import argparse
import json
import re
import subprocess
import sys

# The vocabulary that makes a bead security-shaped. Two lists rather than one,
# because they need different matching rules and merging them reintroduces the
# bug that the split is here to avoid.
#
# Bare common words are deliberately absent. "security", "token", "isolation"
# and "authorization" all appear in routine work, and a gate that fires on them
# fires on everything, which is the same as a gate that fires on nothing.
SECURITY_PHRASES = (
    "access control",
    "auth boundary",
    "authentication boundary",
    "authorization boundary",
    "cross-tenant",
    "data shape",
    "public API surface",
    "row level security",
    "row-level security",
    "security model",
    "tenant isolation",
    "token exposure",
)

# Acronyms match on word boundaries; the phrases above match as plain
# substrings. This is not tidiness. The factory this pack is carved from
# matches everything as a substring, and its gate fires on any description
# containing the word "URLs", because "URLs" contains "RLS". A false fire costs
# a real round-trip: the bead bounces back for a matrix that nothing in it
# needs. Adding an acronym to the phrase list re-creates that, so add it here.
SECURITY_ACRONYMS = (
    "PII",
    "RBAC",
    "RLS",
    "SOC 2",
    "SOC2",
)

# The columns an audit matrix has to name. Order does not matter and extra
# columns are welcome; these four have to be there.
MATRIX_COLUMNS = ("Resource", "Rule", "Threat", "Covered")

# Markdown's separator cell is one or more dashes, with optional alignment
# colons on either end. `|:-:|` is as valid as `| --- |`, and a tutorial's
# checker that rejects the short form teaches a rule markdown does not have.
_SEPARATOR_CELL = re.compile(r"^:?-+:?$")

# Reserved for "this check could not run", never for "this bead failed".
EXIT_CANNOT_RUN = 2


def _cannot_run(message):
    print(f"audit-matrix: {message}", file=sys.stderr)
    sys.exit(EXIT_CANNOT_RUN)


def security_phrase_in(text):
    """Return the vocabulary entry that makes this text security-shaped, or None.

    Phrases first, so a description matching both reports the more specific of
    the two rather than an acronym that happens to sort earlier.
    """
    lowered = text.lower()
    for phrase in SECURITY_PHRASES:
        if phrase.lower() in lowered:
            return phrase
    for acronym in SECURITY_ACRONYMS:
        if re.search(rf"\b{re.escape(acronym)}\b", text, re.IGNORECASE):
            return acronym
    return None


def _table_cells(line):
    """Split one markdown table row into its cells, or return None if it is not one."""
    stripped = line.strip()
    if not stripped.startswith("|"):
        return None
    return [cell.strip() for cell in stripped.strip("|").split("|")]


def _is_separator(line):
    cells = _table_cells(line)
    return bool(cells) and all(_SEPARATOR_CELL.match(cell) for cell in cells)


def find_audit_matrix(text):
    """Return the 1-based line number of the matrix header row, or None.

    A matrix is a header row naming all four columns, the separator row markdown
    requires under it, and at least one row of content. Checking for a real
    table matters more than it looks: the four column names can all appear in a
    paragraph describing what a matrix would contain, and that paragraph is
    exactly the thing this check has to keep telling apart from a matrix.
    """
    wanted = {column.lower() for column in MATRIX_COLUMNS}
    lines = text.splitlines()
    for index, line in enumerate(lines):
        cells = _table_cells(line)
        if not cells or not wanted.issubset({cell.lower() for cell in cells}):
            continue
        if index + 1 >= len(lines) or not _is_separator(lines[index + 1]):
            continue
        body = lines[index + 2] if index + 2 < len(lines) else ""
        if _table_cells(body) and not _is_separator(body):
            return index + 1
    return None


def verdict_for(bead):
    """Classify one bead. Returns a dict; `state` is one of three values.

    `skip`   not security-shaped, so no matrix is expected
    `pass`   security-shaped and the matrix is there
    `needs`  security-shaped and the matrix is missing
    """
    text = "\n".join(filter(None, (bead.get("title"), bead.get("description"))))
    phrase = security_phrase_in(text)
    if phrase is None:
        return {"id": bead.get("id"), "state": "skip", "phrase": None, "line": None}
    line = find_audit_matrix(text)
    return {
        "id": bead.get("id"),
        "state": "pass" if line else "needs",
        "phrase": phrase,
        "line": line,
    }


def _bd_json(args):
    """Run bd and parse its JSON, or exit EXIT_CANNOT_RUN saying which half failed.

    Failing loudly is the point. A gate that treats an unreadable board as a
    clean one passes every bead on the day bd is unavailable, and nothing in the
    output distinguishes that day from a quiet one.
    """
    try:
        completed = subprocess.run(
            ["bd", *args], capture_output=True, text=True, check=True
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        _cannot_run(f"`bd {' '.join(args)}` failed: {exc}")
    try:
        return json.loads(completed.stdout)
    except json.JSONDecodeError:
        _cannot_run(f"`bd {' '.join(args)}` returned no readable JSON")


def _one_bead(payload, asked_for):
    """Pull the requested bead out of `bd show` output, or exit rather than guess.

    Two shapes have to be caught here, and both of them exit 0 from bd.

    An id bd cannot resolve comes back as an object carrying an `error` key
    rather than as a list, so indexing it would fail somewhere further down with
    a message about the wrong thing.

    The other is worse, because it looks like success. `bd show` matches ids as
    substrings, so asking for a bead that does not exist can hand you a
    different one. Asking for an id ending in "nope" came back, on the board
    this was written against, with an unrelated bead whose own id happened to
    carry those four letters in the middle of a longer word. A gate that accepts
    that reports a verdict about a bead nobody asked about, and the verdict
    looks perfectly normal. Compare the id you got against the one you asked
    for.
    """
    if isinstance(payload, dict):
        _cannot_run(f"bd could not resolve {asked_for}")
    if not payload:
        _cannot_run(f"no bead {asked_for}")
    bead = payload[0]
    if bead.get("id") != asked_for:
        _cannot_run(
            f"asked bd for {asked_for} and got {bead.get('id')}; "
            f"refusing to report a verdict on a bead nobody asked about"
        )
    return bead


def cmd_check(args):
    result = verdict_for(_one_bead(_bd_json(["show", args.bead, "--json"]), args.bead))
    if args.json:
        print(json.dumps(result))
    elif result["state"] == "skip":
        print(f"{result['id']}: not security-shaped, no matrix expected")
    elif result["state"] == "pass":
        print(
            f"{result['id']}: security-shaped on \"{result['phrase']}\", "
            f"matrix found at line {result['line']}"
        )
    else:
        print(
            f"{result['id']}: security-shaped on \"{result['phrase']}\", no audit matrix.\n"
            f"Add a table to the description naming {', '.join(MATRIX_COLUMNS)}, "
            f"one row per resource the change touches."
        )
    return 1 if result["state"] == "needs" else 0


def cmd_scan(args):
    """Report every open bead that needs a matrix. Always exits 0.

    An order's exec is a report rather than a verdict, so a non-zero exit here
    would only make `gc order history` look broken on a board doing exactly what
    this pack expects boards to do.
    """
    beads = _bd_json(["list", "--status", "open", "--limit", "0", "--json"])
    if isinstance(beads, dict):
        _cannot_run("bd list returned an error rather than a list of beads")
    results = [verdict_for(bead) for bead in beads]
    needs = [result for result in results if result["state"] == "needs"]
    if args.json:
        print(json.dumps(needs))
        return 0
    for result in needs:
        print(f"{result['id']}\tsecurity-shaped on \"{result['phrase']}\"\tno audit matrix")
    print(
        f"audit-matrix: {len(needs)} of {len(results)} open beads are security-shaped "
        f"and missing a matrix",
        file=sys.stderr,
    )
    return 0


# Planted cases. Every one of these is a shape the detector has to get right and
# that your own board is unlikely to contain, which is the whole reason they are
# written down here instead of being checked by running the tool on real beads.
SELF_TEST_CASES = (
    ("plain work is skipped", "Rename the log helper and update its callers", "skip"),
    (
        "an acronym alone makes it security-shaped",
        "Add an RBAC role for the reporting dashboard",
        "needs",
    ),
    (
        "a phrase alone makes it security-shaped",
        "Tighten access control on the export endpoint",
        "needs",
    ),
    (
        "URLs does not fire on RLS",
        "Rewrite the docs so every one of the URLs resolves",
        "skip",
    ),
    (
        "a real matrix passes",
        "Add row-level security to the reports table\n\n"
        "| Resource | Rule | Threat | Covered |\n"
        "| --- | --- | --- | --- |\n"
        "| reports | tenant_id policy | cross-tenant read | yes |\n",
        "pass",
    ),
    (
        "extra columns and loose alignment still pass",
        "Add row-level security to the reports table\n\n"
        "|Covered|Threat|Rule|Resource|Notes|\n"
        "|:--|:-:|--:|---|---|\n"
        "|yes|cross-tenant read|tenant_id policy|reports|-|\n",
        "pass",
    ),
    (
        "the column names in prose are not a matrix",
        "Add row-level security to the reports table. The matrix should say, per "
        "Resource, which Rule covers it, which Threat it defends against, and "
        "whether it is Covered.",
        "needs",
    ),
    (
        "a header with no rows under it is not a matrix",
        "Add row-level security to the reports table\n\n"
        "| Resource | Rule | Threat | Covered |\n"
        "| --- | --- | --- | --- |\n",
        "needs",
    ),
    (
        "an unrelated table does not stand in for the matrix",
        "Add row-level security to the reports table\n\n"
        "| Step | Owner |\n| --- | --- |\n| migrate | you |\n",
        "needs",
    ),
)


def cmd_self_test(_args):
    failures = []
    for name, description, expected in SELF_TEST_CASES:
        actual = verdict_for({"id": "probe", "description": description})["state"]
        status = "ok" if actual == expected else "FAIL"
        if actual != expected:
            failures.append(name)
        print(f"{status:4}  {name}: expected {expected}, got {actual}")
    print(f"\n{len(SELF_TEST_CASES) - len(failures)}/{len(SELF_TEST_CASES)} cases passed")
    return 1 if failures else 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--self-test", action="store_true", help="run the planted cases and exit"
    )
    sub = parser.add_subparsers(dest="command")

    p_check = sub.add_parser("check", help="check one bead")
    p_check.add_argument("bead", help="bead id")
    p_check.add_argument("--json", action="store_true", help="emit the verdict as JSON")
    p_check.set_defaults(func=cmd_check)

    p_scan = sub.add_parser("scan", help="report every open bead that needs a matrix")
    p_scan.add_argument("--json", action="store_true", help="emit the findings as JSON")
    p_scan.set_defaults(func=cmd_scan)

    args = parser.parse_args(argv)
    if args.self_test:
        return cmd_self_test(args)
    if not getattr(args, "func", None):
        parser.print_help()
        return 2
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
