#!/usr/bin/env python3
"""Validate every relative link and every heading anchor in this repo's markdown.

Two things separate this from the shell checker it replaces. It discovers markdown
by walking the tree rather than by naming directories, so a directory added next
week is covered the day it lands. And it tests the ``#fragment`` instead of
throwing it away, which is where the majority of dead references live.

Run it with no arguments to check the whole repo:

    scripts/check-links.sh

Exit status is 0 when nothing is broken and 1 when something is. Two extra modes
prove the checker itself is honest: ``--self-test`` plants a deliberately broken
link in every directory that holds markdown and fails unless all of them are
caught, and ``--verify-anchors`` diffs the anchor ids computed here against the
ones GitHub's own renderer emits.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import unicodedata
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

# Directories never worth walking, named one by one. This is the *only* thing that
# narrows the walk: an allowlist of directories to visit is the defect this checker
# exists to end, so anything absent from this set is checked, including directories
# that do not exist yet.
#
# Note what is deliberately missing: a rule skipping every name that starts with a
# dot. That rule reads as housekeeping and behaves as a second, invisible allowlist,
# and it hides `.github/`, where CONTRIBUTING.md and the issue and pull-request
# templates live, all of them carrying relative links. Naming `.github` as an
# exception would fix that one directory and leave `.gitlab/`, `.circleci/` and
# `.devcontainer/` hidden, which is the same defect one size smaller. Every entry
# below is a build cache or a dependency tree, so the list grows only when a tool
# adds one.
IGNORED_DIRS = {
    ".git",
    ".mypy_cache",
    ".pytest_cache",
    ".ruff_cache",
    ".tox",
    ".venv",
    "__pycache__",
    "node_modules",
    "venv",
}

# The directory list the shell checker used to walk, kept so --legacy-scope can
# reproduce the old numbers alongside the new ones. Nothing else reads it.
LEGACY_SCOPE = ("progression", "hardening")

PROBE_PREFIX = "link-check-probe-"

SKIP_SCHEMES = ("http://", "https://", "mailto:", "tel:", "ftp://")


# --------------------------------------------------------------------------
# Markdown scanning
# --------------------------------------------------------------------------

FENCE_RE = re.compile(r"^ {0,3}(?P<char>`{3,}|~{3,})(?P<info>.*)$")
ATX_RE = re.compile(r"^ {0,3}(?P<hashes>#{1,6})(?:[ \t]+(?P<text>.*?))?[ \t]*$")
SETEXT_RE = re.compile(r"^ {0,3}(?P<char>=+|-+)[ \t]*$")
LINK_DEF_RE = re.compile(r"^ {0,3}\[(?P<label>[^\]]+)\]:\s*(?P<dest>\S+)")
HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)

# A setext underline turns the paragraph above it into a heading, but only when
# that line is a paragraph. `-` under `-` is two empty list items, and a row of
# dashes under a table header is the table's own separator.
NOT_A_PARAGRAPH_RE = re.compile(r"^ {0,3}(?:[-*+](?:[ \t]|$)|\d+[.)](?:[ \t]|$)|>|\||#)")


def strip_frontmatter(text: str) -> tuple[str, int]:
    """Drop leading YAML frontmatter, returning the body and the lines removed.

    GitHub strips frontmatter when it renders a file in its repo, so a heading
    computed from those lines would be an anchor no reader can ever reach. The
    bare ``/markdown`` API has no repo context and renders it as content, which
    is the one expected disagreement in ``--verify-anchors``; stripping it on
    both sides is what keeps that check meaningful.
    """
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return text, 0
    for i in range(1, len(lines)):
        if lines[i].strip() in ("---", "..."):
            return "\n".join(lines[i + 1 :]), i + 1
    return text, 0


def blank_html_comments(text: str) -> str:
    """Blank out HTML comments, preserving line count and column offsets.

    A commented-out link is not a link. Replacing each non-newline character with
    a space keeps every later line number and column exactly where it was.
    """

    def _blank(match: re.Match[str]) -> str:
        return "".join("\n" if ch == "\n" else " " for ch in match.group(0))

    return HTML_COMMENT_RE.sub(_blank, text)


def blank_code_spans(line: str) -> str:
    """Blank the contents of inline code spans on one line, keeping its length.

    ``See `[a](b)` for the shape`` contains no link. Backtick runs match by equal
    length, which is CommonMark's rule for code-span delimiters.
    """
    out = list(line)
    i = 0
    n = len(line)
    while i < n:
        if line[i] != "`":
            i += 1
            continue
        run = 1
        while i + run < n and line[i + run] == "`":
            run += 1
        opener = line[i : i + run]
        close = line.find(opener, i + run)
        # A closing run must be exactly this long, not merely at least this long.
        while close != -1 and close + run < n and line[close + run] == "`":
            close = line.find(opener, close + run)
        if close == -1:
            i += run
            continue
        for j in range(i, close + run):
            out[j] = " "
        i = close + run
    return "".join(out)


def strip_inline(text: str) -> str:
    """Reduce heading source to the text GitHub renders, which is what it slugs.

    ``## The [gc](x) command`` renders as ``The gc command``. Slugging the source
    instead would keep the URL and produce an id no link can ever match.
    """
    text = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", text)  # images contribute no text
    text = re.sub(r"!\[[^\]]*\]\[[^\]]*\]", "", text)
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)  # inline links
    text = re.sub(r"\[([^\]]*)\]\[[^\]]*\]", r"\1", text)  # reference links
    text = re.sub(r"<[^>]+>", "", text)  # raw HTML tags
    text = text.replace("`", "")  # code spans keep their contents
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
    text = re.sub(r"__([^_]+)__", r"\1", text)
    text = re.sub(r"\*([^*]+)\*", r"\1", text)
    text = re.sub(r"(?<![\w])_([^_]+)_(?![\w])", r"\1", text)
    text = re.sub(r"~~([^~]+)~~", r"\1", text)
    text = re.sub(r"\\(.)", r"\1", text)  # backslash escapes
    return text


def slugify(text: str) -> str:
    """Apply the github-slugger transform.

    Lowercase, drop everything that is not a letter, digit, mark, underscore or
    ASCII hyphen, then map each remaining space to one hyphen. Punctuation is
    *removed* rather than replaced, and the spaces that flanked it survive as
    hyphens of their own: ``gemini … --state-mode`` becomes ``gemini----state-mode``.
    """
    text = text.strip().lower()
    kept = []
    for ch in text:
        if ch in "-_ ":
            kept.append(ch)
        elif unicodedata.category(ch)[0] in ("L", "N", "M"):
            kept.append(ch)
    return "".join(kept).replace(" ", "-")


@dataclass
class Link:
    line: int
    raw: str
    dest: str
    fragment: str


@dataclass
class Document:
    path: Path
    headings: list[str] = field(default_factory=list)
    anchors: set[str] = field(default_factory=set)
    links: list[Link] = field(default_factory=list)
    ref_defs: dict[str, str] = field(default_factory=dict)
    ref_links: list[Link] = field(default_factory=list)


def parse(path: Path, root: Path) -> Document:
    doc = Document(path=path)
    text, offset = strip_frontmatter(path.read_text(encoding="utf-8", errors="replace"))
    text = blank_html_comments(text)
    lines = text.split("\n")

    fence_char = ""
    fence_len = 0
    slug_counts: Counter[str] = Counter()
    prev_line = ""

    def record_heading(raw_text: str) -> None:
        rendered = strip_inline(raw_text).strip()
        base = slugify(rendered)
        if not base:
            return
        seen = slug_counts[base]
        slug_counts[base] += 1
        doc.anchors.add(base if seen == 0 else f"{base}-{seen}")
        doc.headings.append(rendered)

    for lineno, line in enumerate(lines, start=1 + offset):
        fence = FENCE_RE.match(line)
        if fence_char:
            # Only a bare run of the same character, at least as long as the
            # opener, closes a fence. A run carrying an info string does not,
            # which is how a nested ```yaml block fails to close its parent.
            if (
                fence
                and fence.group("char")[0] == fence_char
                and len(fence.group("char")) >= fence_len
                and not fence.group("info").strip()
            ):
                fence_char = ""
                fence_len = 0
            prev_line = line
            continue
        if fence:
            info = fence.group("info")
            if fence.group("char")[0] == "`" and "`" in info:
                pass  # not a fence opener: backtick info strings cannot hold backticks
            else:
                fence_char = fence.group("char")[0]
                fence_len = len(fence.group("char"))
                prev_line = line
                continue

        atx = ATX_RE.match(line)
        if atx:
            raw = (atx.group("text") or "").strip()
            raw = re.sub(r"[ \t]+#+[ \t]*$", "", raw)  # optional closing sequence
            record_heading(raw)
            prev_line = line
            continue

        setext = SETEXT_RE.match(line)
        if (
            setext
            and prev_line.strip()
            and not prev_line.startswith(" " * 4)
            and not NOT_A_PARAGRAPH_RE.match(prev_line)
            and not FENCE_RE.match(prev_line)
        ):
            # `---` under a paragraph is a level-2 heading; under nothing it is a
            # thematic break, and under a list item or a table header row it
            # belongs to that construct instead.
            record_heading(prev_line.strip())
            prev_line = line
            continue

        scan = blank_code_spans(line)

        ref_def = LINK_DEF_RE.match(scan)
        if ref_def:
            doc.ref_defs[ref_def.group("label").strip().lower()] = ref_def.group("dest")
            prev_line = line
            continue

        for match in re.finditer(r"\[(?:[^\[\]]|\[[^\]]*\])*\]\(([^()\s]*)(?:\s+\"[^\"]*\")?\)", scan):
            dest = match.group(1)
            if dest.startswith("<") and dest.endswith(">"):
                dest = dest[1:-1]
            path_part, _, fragment = dest.partition("#")
            doc.links.append(Link(lineno, match.group(0), path_part, fragment))

        # Reference links, and the two limits worth knowing before you trust this
        # pass. A collapsed `[Foo][]` looks up the empty label rather than `foo`,
        # so it resolves to nothing and is skipped. A reference whose definition
        # is missing is skipped too, rather than reported: `[1-9][0-9]` is a
        # character class this repo writes in prose, and it is indistinguishable
        # here from a link to an undefined label. Both stay quiet because the repo
        # has no reference-style definitions at all. Add the definitions and these
        # two want revisiting together.
        for match in re.finditer(r"\[(?:[^\[\]]|\[[^\]]*\])*\]\[([^\]]*)\]", scan):
            doc.ref_links.append(Link(lineno, match.group(0), match.group(1).strip().lower(), ""))

        prev_line = line

    return doc


# --------------------------------------------------------------------------
# Discovery
# --------------------------------------------------------------------------


def discover(root: Path, legacy_scope: bool = False) -> list[Path]:
    """Find markdown by walking the tree, not by naming the directories to visit."""
    if legacy_scope:
        files = sorted(p for p in root.glob("*.md") if p.is_file())
        for name in LEGACY_SCOPE:
            files.extend(sorted((root / name).rglob("*.md")))
        return sorted(set(files))

    found: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in IGNORED_DIRS)
        for name in sorted(filenames):
            if name.lower().endswith(".md"):
                found.append(Path(dirpath) / name)
    return sorted(found)


# --------------------------------------------------------------------------
# Checking
# --------------------------------------------------------------------------


@dataclass
class Report:
    files: int = 0
    file_links_checked: int = 0
    file_links_broken: list[str] = field(default_factory=list)
    anchors_checked: int = 0
    anchors_broken: list[str] = field(default_factory=list)
    unchecked: list[str] = field(default_factory=list)


def check(root: Path, files: list[Path]) -> Report:
    docs: dict[Path, Document] = {}
    for path in files:
        docs[path.resolve()] = parse(path, root)

    report = Report(files=len(files))

    for path in files:
        doc = docs[path.resolve()]
        rel = path.relative_to(root)

        for link in list(doc.links) + [
            Link(rl.line, rl.raw, *_resolve_ref(doc, rl)) for rl in doc.ref_links
        ]:
            dest = link.dest
            if dest.startswith(SKIP_SCHEMES):
                continue

            if not dest:
                # Pure anchor: [Foo](#bar) points into this same file. The shell
                # checker's regex could not even match this shape, so these links
                # were never counted, let alone tested.
                if not link.fragment:
                    continue
                report.anchors_checked += 1
                if link.fragment.lower() not in doc.anchors:
                    report.anchors_broken.append(
                        f"{rel}:{link.line}: dead anchor -> #{link.fragment}"
                    )
                continue

            target = (root / dest[1:]) if dest.startswith("/") else (path.parent / dest)
            target = Path(os.path.normpath(target))

            report.file_links_checked += 1
            if not target.exists():
                report.file_links_broken.append(
                    f"{rel}:{link.line}: broken link -> {dest}"
                    f"{'#' + link.fragment if link.fragment else ''}"
                )
                continue

            if not link.fragment:
                continue

            report.anchors_checked += 1
            target_doc = docs.get(target.resolve())
            if target_doc is None:
                if target.suffix.lower() == ".md":
                    target_doc = parse(target, root)
                    docs[target.resolve()] = target_doc
                else:
                    report.unchecked.append(
                        f"{rel}:{link.line}: fragment on a non-markdown target, not checked"
                        f" -> {dest}#{link.fragment}"
                    )
                    report.anchors_checked -= 1
                    continue

            if link.fragment.lower() not in target_doc.anchors:
                report.anchors_broken.append(
                    f"{rel}:{link.line}: dead anchor -> {dest}#{link.fragment}"
                )

    return report


def _resolve_ref(doc: Document, link: Link) -> tuple[str, str]:
    dest = doc.ref_defs.get(link.dest, "")
    path_part, _, fragment = dest.partition("#")
    return path_part, fragment


# --------------------------------------------------------------------------
# Self-test: prove the traversal actually opens every directory
# --------------------------------------------------------------------------

# The edges of the github-slugger transform, each one a case a hand-derived
# anchor gets wrong. `--verify-anchors` is the authoritative check against the
# real renderer; these run offline so a contributor with no network still gets
# told when a change to slugify() breaks one of them.
SLUG_CASES = (
    ("gemini … --state-mode", "gemini----state-mode"),  # dropped punctuation leaves its spaces
    ("Foo — bar", "foo--bar"),                          # em-dash goes, the two spaces stay
    ("If you are on a box, `~/.local/bin` still matters",
     "if-you-are-on-a-box-localbin-still-matters"),
    ("What's next", "whats-next"),
    ("Option A: Local Factory Check", "option-a-local-factory-check"),
    ("1. Clone the tutorial", "1-clone-the-tutorial"),
    ("Café niño", "café-niño"),                         # non-ASCII letters survive
    ("snake_case_name", "snake_case_name"),             # so does the underscore
    ("The [gc](https://example.com) command", "the-gc-command"),  # links render as their label
)


def check_slug_cases() -> list[str]:
    failures = []
    for text, want in SLUG_CASES:
        got = slugify(strip_inline(text))
        if got != want:
            failures.append(f"  slug({text!r}) -> {got!r}, expected {want!r}")
    return failures


def self_test(root: Path, legacy_scope: bool = False) -> int:
    """Plant a broken link in every markdown-bearing directory and demand a catch.

    A checker that reports zero because it is still not looking is the failure
    this exists to detect, and only a planted positive can tell the two apart.

    Probes go into every directory either way. ``legacy_scope`` narrows only the
    pass that looks for them, which makes ``--self-test --legacy-scope`` the
    positive control: it is expected to fail, and it names the directories the
    old enumerated traversal never opened.
    """
    slug_failures = check_slug_cases()
    if slug_failures:
        print(f"self-test: {len(slug_failures)} of {len(SLUG_CASES)} slug case(s) wrong")
        for line in slug_failures:
            print(line)
        return 1
    print(f"self-test: {len(SLUG_CASES)} slug transform case(s) correct")

    dirs = sorted({p.parent for p in discover(root)})
    probes = [d / f"{PROBE_PREFIX}{os.getpid()}.md" for d in dirs]

    # Each probe carries one of each defect class, so a pass proves the file
    # pass and the anchor pass are both live. A probe with only a bad path would
    # leave a silently no-op anchor check indistinguishable from a working one.
    body = (
        "# Probe\n\n"
        "[deliberately broken path](./no-such-file-{pid}.md)\n\n"
        "[deliberately dead anchor](#no-such-heading-{pid})\n"
    )

    planted: list[Path] = []
    try:
        for probe in probes:
            probe.write_text(body.format(pid=os.getpid()), encoding="utf-8")
            planted.append(probe)

        report = check(root, discover(root, legacy_scope=legacy_scope))
        paths_caught = {line.split(":", 1)[0] for line in report.file_links_broken}
        anchors_caught = {line.split(":", 1)[0] for line in report.anchors_broken}

        missed = [
            p for p in planted
            if str(p.relative_to(root)) not in paths_caught
            or str(p.relative_to(root)) not in anchors_caught
        ]
        scope = "legacy directory list" if legacy_scope else "whole tree"
        print(f"self-test ({scope}): planted {len(planted)} probe(s) across {len(dirs)} directory(ies)")
        for probe in planted:
            rel = str(probe.relative_to(root))
            marks = []
            marks.append("path" if rel in paths_caught else "PATH-MISSED")
            marks.append("anchor" if rel in anchors_caught else "ANCHOR-MISSED")
            print(f"  {'caught' if rel not in {p.relative_to(root).as_posix() for p in missed} else 'MISSED'}"
                  f"  [{', '.join(marks)}]  {rel}")
        if missed:
            print(f"\nself-test FAILED: {len(missed)} probe(s) not fully caught.")
            return 1
        print("\nself-test passed: every directory holding markdown is traversed,"
              " and both the path and the anchor pass caught their planted defect.")
        return 0
    finally:
        for probe in planted:
            probe.unlink(missing_ok=True)


# --------------------------------------------------------------------------
# Cross-check the slug transform against GitHub's own renderer
# --------------------------------------------------------------------------


def verify_anchors(root: Path) -> int:
    """Diff computed anchor ids against the ids GitHub's /markdown endpoint emits.

    Any disagreement is a bug in one of the two, and it is usually this one.
    Needs the `gh` CLI authenticated; it is a maintenance check, not part of the
    normal run.
    """
    files = discover(root)
    disagreements = 0
    for path in files:
        rel = path.relative_to(root)
        source, _ = strip_frontmatter(path.read_text(encoding="utf-8"))
        try:
            rendered = subprocess.run(
                ["gh", "api", "-X", "POST", "/markdown", "-f", "mode=markdown",
                 "-f", f"text={source}"],
                capture_output=True, text=True, check=True,
            ).stdout
        except (subprocess.CalledProcessError, FileNotFoundError) as exc:
            print(f"{rel}: could not reach the renderer ({exc})", file=sys.stderr)
            return 2

        theirs = [m for m in re.findall(r'id="user-content-([^"]*)"', rendered)]
        ours = []
        counts: Counter[str] = Counter()
        doc = parse(path, root)
        for heading in doc.headings:
            base = slugify(heading)
            seen = counts[base]
            counts[base] += 1
            ours.append(base if seen == 0 else f"{base}-{seen}")

        if ours != theirs:
            disagreements += 1
            only_ours = [a for a in ours if a not in theirs]
            only_theirs = [a for a in theirs if a not in ours]
            print(f"{rel}: {len(ours)} computed, {len(theirs)} rendered")
            for a in only_ours:
                print(f"    computed but not rendered: {a}")
            for a in only_theirs:
                print(f"    rendered but not computed: {a}")

    print(f"\nanchor-verify: {len(files)} file(s), {disagreements} disagreeing with GitHub.")
    return 1 if disagreements else 0


# --------------------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=None, help="repo root (default: the repo this script lives in)")
    parser.add_argument("--legacy-scope", action="store_true",
                        help="walk only the directories the old shell checker walked, for comparison")
    parser.add_argument("--no-anchors", action="store_true", help="check file paths only")
    parser.add_argument("--self-test", action="store_true",
                        help="plant a broken link in every markdown directory and demand a catch")
    parser.add_argument("--verify-anchors", action="store_true",
                        help="diff computed anchor ids against GitHub's renderer (needs gh)")
    args = parser.parse_args()

    root = Path(args.root).resolve() if args.root else Path(__file__).resolve().parent.parent

    if args.self_test:
        return self_test(root, legacy_scope=args.legacy_scope)
    if args.verify_anchors:
        return verify_anchors(root)

    files = discover(root, legacy_scope=args.legacy_scope)
    leftovers = [p for p in files if p.name.startswith(PROBE_PREFIX)]
    if leftovers:
        print("warning: leftover self-test probe files present:", file=sys.stderr)
        for p in leftovers:
            print(f"  {p.relative_to(root)}", file=sys.stderr)

    report = check(root, files)

    for line in report.file_links_broken:
        print(line)
    if not args.no_anchors:
        for line in report.anchors_broken:
            print(line)
    for line in report.unchecked:
        print(line)

    scope = "legacy directory list" if args.legacy_scope else "whole tree"
    print(f"\nlink-check ({scope}): {report.files} markdown file(s)")
    print(f"  file links: {report.file_links_checked} checked, {len(report.file_links_broken)} broken")
    if args.no_anchors:
        print("  anchors:    not checked (--no-anchors)")
    else:
        print(f"  anchors:    {report.anchors_checked} checked, {len(report.anchors_broken)} broken")

    broken = len(report.file_links_broken)
    if not args.no_anchors:
        broken += len(report.anchors_broken)
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main())
