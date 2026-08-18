#!/usr/bin/env python3
"""Prove every hardening option installs on the base factory and nothing else.

The options are a menu rather than a ladder: a participant picks any one of them
from the base factory, in any order, without having done the one before it. That
promise is easy to state and easy to break, because a pack can go on importing
another option long after its page stops saying so.

Four kinds of reference can point outside a pack, and only the first two fail at
import time:

* ``[[patches.agent]]`` names an agent the pack means to override.
* a formula's ``extends`` names a formula it means to build on.
* a formula step or a prompt runs ``gc sling <agent>``, which composition never
  reads, so a pack can import cleanly and still dispatch to an agent that is not
  installed. That is the one this was written for.
* an option **page** tells the reader to run ``gc sling <rig>/<pack>.<agent>``.
  The page is the participant's copy-and-paste source, so a command that names an
  agent the pack cannot reach fails in the room rather than in CI. The pack half
  of that address is what makes it checkable: it says which import chain the
  agent is expected to resolve through.

A target defined by no pack in this repo comes from the base gastown install
(``mol-polecat-base`` is the live example) and is reported as external. A target
defined by some pack here but unreachable from the pack that names it is the
regression, and it fails the run.

    scripts/check_packs.py                 # check artifacts/packs and the pages
    scripts/check_packs.py --self-test     # prove the checker actually catches one

Exit status is 0 when every reference resolves and 1 when any does not.
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
import tempfile
from pathlib import Path

SLING_RE = re.compile(r"gc sling\s+\\?\"?([^\s\"\\]+)")

# `gc sling <rig>/<pack>.<agent>` as an option page writes it. The rig segment is
# the participant's rig name and carries no information here; the pack segment is
# the one that decides which chain the agent has to resolve through.
PAGE_SLING_RE = re.compile(r"gc sling\s+([A-Za-z0-9_.-]+)/([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)")


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def imports_of(pack: Path) -> list[str]:
    return re.findall(r"^\[imports\.([^\]]+)\]", read(pack / "pack.toml"), re.M)


def agents_of(pack: Path) -> set[str]:
    d = pack / "agents"
    return {x.name for x in d.iterdir() if x.is_dir()} if d.is_dir() else set()


def formula_name(path: Path) -> str:
    """``mol-x.formula.toml`` and ``mol-x.toml`` both name the formula ``mol-x``."""
    for suffix in (".formula.toml", ".toml"):
        if path.name.endswith(suffix):
            return path.name[: -len(suffix)]
    return path.name


def formulas_of(pack: Path) -> set[str]:
    d = pack / "formulas"
    return {formula_name(f) for f in d.iterdir() if f.name.endswith(".toml")} if d.is_dir() else set()


def orders_of(pack: Path) -> set[str]:
    d = pack / "orders"
    return {f.stem for f in d.iterdir() if f.suffix == ".toml"} if d.is_dir() else set()


def patch_targets(pack: Path) -> list[str]:
    out = []
    for block in re.split(r"^\[\[patches\.agent\]\]", read(pack / "pack.toml"), flags=re.M)[1:]:
        m = re.search(r'^\s*name\s*=\s*"([^"]+)"', block, re.M)
        if m:
            out.append(m.group(1))
    return out


def extends_targets(pack: Path) -> list[tuple[str, str]]:
    """``extends`` is a TOML array of formula names; a bare string is accepted too."""
    out = []
    d = pack / "formulas"
    if not d.is_dir():
        return out
    for f in sorted(d.iterdir()):
        if not f.name.endswith(".toml"):
            continue
        for m in re.finditer(r"^\s*extends\s*=\s*(.+)$", read(f), re.M):
            out.extend((f.name, name) for name in re.findall(r'"([^"]+)"', m.group(1)))
    return out


def sling_targets(pack: Path) -> list[tuple[str, str]]:
    out = []
    for f in sorted(pack.rglob("*")):
        if not f.is_file() or f.suffix not in (".toml", ".md"):
            continue
        for m in SLING_RE.finditer(read(f)):
            raw = m.group(1)
            # A `<rig>/` placeholder is prose showing a reader what to type, and
            # it names a rig this pack is not composed with. Skipping it here is
            # what keeps every documented example from reading as a break.
            if "<" in raw:
                continue
            name = re.sub(r".*[/}]", "", raw)  # drop rig and binding prefixes
            if not name or "$" in name or "{" in name:
                continue
            out.append((f.relative_to(pack).as_posix(), name))
    return out


def page_sling_targets(docs_root: Path, packs_dir: Path) -> list[tuple[Path, int, str, str]]:
    """Every ``gc sling <rig>/<pack>.<agent>`` written in a page, with its line.

    Scans the whole tree bar the packs themselves, which ``sling_targets`` already
    covers under the pack that owns them. Returns the line number so a failure
    names somewhere to go and fix, which is the difference between this being a
    gate and being a puzzle.
    """
    out = []
    for page in sorted(docs_root.rglob("*.md")):
        if packs_dir in page.parents:
            continue
        for lineno, line in enumerate(read(page).splitlines(), 1):
            for m in PAGE_SLING_RE.finditer(line):
                _rig, pack, agent = m.groups()
                out.append((page, lineno, pack, agent))
    return out


def owner_of(agent: str, packs: list[Path]) -> str:
    """Which pack defines this agent — the half of a page failure that says what to do."""
    for pack in packs:
        if agent in agents_of(pack):
            return pack.name
    return "no pack here"


def closure(packs_dir: Path, pack: Path, seen: list[Path] | None = None) -> list[Path]:
    seen = seen if seen is not None else []
    if pack.name in [p.name for p in seen]:
        return seen
    seen.append(pack)
    for name in imports_of(pack):
        target = packs_dir / name
        if target.is_dir():
            closure(packs_dir, target, seen)
        else:
            print(f"  !! {pack.name}: imports.{name} resolves to no pack directory")
    return seen


def check(packs_dir: Path, quiet: bool = False, docs_root: Path | None = None) -> int:
    packs = sorted(p for p in packs_dir.iterdir() if (p / "pack.toml").is_file())
    if not packs:
        print(f"no packs found under {packs_dir}", file=sys.stderr)
        return 1

    all_agents: set[str] = set().union(*(agents_of(p) for p in packs))
    all_formulas: set[str] = set().union(*(formulas_of(p) for p in packs))

    def emit(msg: str) -> None:
        if not quiet:
            print(msg)

    emit(f"{len(packs)} packs under {packs_dir}")
    emit(f"defined here: {len(all_agents)} agents, {len(all_formulas)} formulas\n")

    failures: list[str] = []
    checked = 0

    for pack in packs:
        chain = closure(packs_dir, pack)
        reachable_agents: set[str] = set().union(*(agents_of(p) for p in chain))
        reachable_formulas: set[str] = set().union(*(formulas_of(p) for p in chain))
        emit(f"{pack.name}\n  chain: {' -> '.join(p.name for p in chain)}")

        def verdict(target: str, reachable: set[str], universe: set[str], label: str) -> str:
            nonlocal checked
            checked += 1
            if target in reachable:
                return "resolves"
            if target not in universe:
                return "external (builtin)"
            failures.append(f"{pack.name}: {label} {target!r} is defined here but not reachable")
            return "UNRESOLVABLE"

        for target in patch_targets(pack):
            emit(f"  patches.agent {target!r}: {verdict(target, reachable_agents, all_agents, 'patches.agent')}")

        for fname, target in extends_targets(pack):
            v = verdict(target, reachable_formulas, all_formulas, f"{fname} extends")
            emit(f"  {fname} extends {target!r}: {v}")

        for fname, target in sling_targets(pack):
            v = verdict(target, reachable_agents, all_agents, f"{fname} slings")
            emit(f"  {fname} slings {target!r}: {v}")

        if orders_of(pack):
            emit(f"  orders: {', '.join(sorted(orders_of(pack)))}")
        emit("")

    if docs_root is not None:
        by_pack = {p.name: p for p in packs}
        pages_checked = 0
        for page, lineno, pack_name, agent in page_sling_targets(docs_root, packs_dir):
            pack = by_pack.get(pack_name)
            if pack is None:
                # The page named something that is not a pack here. Most often a
                # rig or binding prefix rather than a pack, so it is not ours to
                # judge; the pack-internal pass owns anything defined in-tree.
                continue
            pages_checked += 1
            checked += 1
            reachable: set[str] = set().union(*(agents_of(p) for p in closure(packs_dir, pack)))
            if agent in reachable or agent not in all_agents:
                continue
            where = page.relative_to(docs_root).as_posix()
            failures.append(
                f"{where}:{lineno}: slings '{pack_name}.{agent}', which "
                f"{pack_name} cannot reach (defined in {owner_of(agent, packs)})"
            )
        emit(f"{pages_checked} page sling target(s) checked across the docs tree\n")

    emit(f"{checked} target(s) checked")
    for f in failures:
        print(f"BROKEN: {f}")
    print("FAIL" if failures else "PASS", f"({len(failures)} unresolvable)")
    return 1 if failures else 0


def self_test(packs_dir: Path) -> int:
    """Copy the packs, break one reference of each kind, and require a catch.

    A checker that scans nothing passes every clean tree, so the only evidence
    that this one reads the files is that it fails when the files are wrong.
    """
    # Each probe has to name something this repo defines but the mutated pack
    # cannot reach. Pointing a reference at a target the pack already reaches
    # breaks nothing, and a probe that breaks nothing proves nothing.
    cases = [
        ("extends", "domain-reviewers-rig/formulas/mol-refinery-domain-patrol.formula.toml",
         'extends = ["mol-refinery-pr-patrol"]', 'extends = ["mol-bead-review"]'),
        ("sling", "principles-loop-rig/formulas/mol-principles-review.formula.toml",
         "{{binding_prefix}}architect", "{{binding_prefix}}adr-reviewer"),
        ("patches.agent", "domain-reviewers-rig/pack.toml",
         'name = "refinery"', 'name = "project-manager"'),
    ]

    caught = 0
    for label, rel, old, new in cases:
        with tempfile.TemporaryDirectory() as tmp:
            mutant = Path(tmp) / "packs"
            shutil.copytree(packs_dir, mutant)
            target = mutant / rel
            text = read(target)
            if old not in text:
                print(f"self-test SETUP FAILED: {label}: {old!r} not present in {rel}")
                print("  the tree moved under this probe; update the case rather than the verdict")
                return 1
            # Sever the import too, so the probe cannot resolve by another path.
            target.write_text(text.replace(old, new, 1), encoding="utf-8")
            rc = check(mutant, quiet=True)
            if rc == 0:
                print(f"self-test FAILED: {label}: broke {rel} and the checker still passed")
                return 1
            caught += 1
            print(f"self-test: {label} probe caught")

    # The page probe needs a docs tree as well as packs, so it builds its own.
    # Writing the bad page rather than mutating a real one keeps the probe honest
    # when the pages are all correct, which is the state this gate exists to hold.
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        mutant = root / "packs"
        shutil.copytree(packs_dir, mutant)
        offender = next(
            (p.name for p in sorted(mutant.iterdir())
             if (p / "pack.toml").is_file() and "project-manager" not in agents_of(p)),
            None,
        )
        if offender is None:
            print("self-test SETUP FAILED: page: every pack defines project-manager")
            return 1
        (root / "hardening").mkdir()
        (root / "hardening" / "99-probe.md").write_text(
            f"Run it:\n\n```bash\ngc sling ascii-art/{offender}.project-manager $BEAD --on mol-bead-review\n```\n",
            encoding="utf-8",
        )
        if check(mutant, quiet=True, docs_root=root) == 0:
            print("self-test FAILED: page: a page slung an unreachable agent and the checker passed")
            return 1
        caught += 1
        print("self-test: page sling probe caught")

    print(f"\nself-test passed: {caught} of {len(cases) + 1} probe(s) caught")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--packs", default=None, help="packs directory (default: artifacts/packs beside this repo)")
    parser.add_argument("--docs", default=None,
                        help="docs tree whose pages get their sling commands resolved (default: the repo root)")
    parser.add_argument("--self-test", action="store_true",
                        help="plant a broken reference of each kind and fail unless each is caught")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    packs_dir = Path(args.packs) if args.packs else repo_root / "artifacts" / "packs"
    if not packs_dir.is_dir():
        print(f"no such packs directory: {packs_dir}", file=sys.stderr)
        return 1

    docs_root = Path(args.docs) if args.docs else repo_root
    if not docs_root.is_dir():
        print(f"no such docs directory: {docs_root}", file=sys.stderr)
        return 1

    return self_test(packs_dir) if args.self_test else check(packs_dir, docs_root=docs_root)


if __name__ == "__main__":
    sys.exit(main())
