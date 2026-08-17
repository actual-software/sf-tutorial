#!/usr/bin/env python3
"""Gate an order on a boolean knob the operator sets in ``$FACTORY_ROOT/.env``.

Why this exists
---------------
The controller runs an order's ``exec`` or ``check`` line through ``sh -c`` with
the *controller's own* environment plus a controller-owned set of ``GC_*`` and
``BEADS_*`` variables. The city's ``.env`` is never loaded into it. So a line
that gates itself with an inline shell test —

    check = "test \\"${DAILY_INTROSPECT:-true}\\" != \\"false\\" && ..."

reads an unset variable on every tick, and the on-by-default branch always wins.
An operator who follows the documented instruction to put
``DAILY_INTROSPECT=false`` in ``$FACTORY_ROOT/.env`` gets no error and no effect.

This is worth knowing even if you never use this script, because every factory
that writes its own environment gates hits it. The failure hides for a long
time, since "unset" and "true" mean the same thing to an on-by-default gate: the
knob appears to work in the one direction that needs no knob at all, and it
surfaces the first time somebody tries to turn something off.

Pack scripts invoked as ``$PACK_DIR/assets/scripts/foo.py`` never had the
problem, because they load ``.env`` themselves. This helper carries that
behaviour to the gates, so the TOML line stays trivial:

    check = "$PACK_DIR/assets/scripts/order_env_gate.py DAILY_INTROSPECT && ..."

Contract
--------
``order_env_gate.py NAME [--default VALUE] [--closed-value VALUE]``

Exit 0
    The gate is **open**; the caller should proceed. Unset, empty, or any value
    other than the closed one produces this.
Exit 1
    The gate is **closed**. The variable resolved to the closed value (``false``
    by default), so the caller should skip its action.

Where the value comes from, highest precedence first:

1. The process environment, when the variable is set and non-empty. An operator
   who exports the knob before starting the city still wins over the file.
2. The first ``.env`` that defines it, searched in this order: ``$FACTORY_ROOT``,
   ``$GC_CITY_PATH``, the current directory, then the nearest ancestor of the
   cwd (and of this script) holding a ``city.toml``.
3. ``--default``, which is ``true`` so gates stay on by default.

``$GC_CITY_PATH`` is the anchor that matters for an order. The controller sets
it on every dispatch and it stays correct for a rig-scoped order, whose working
directory is the rig root rather than the city.

Only an exact match against the closed value shuts the gate. That is deliberate
parity with the ``test "${VAR:-true}" != "false"`` line it replaces: unset,
empty, ``true``, ``1`` and ``yes`` all leave it open.

Polarity is configurable, so a gate with the opposite sense can reuse this.
On-by-default is the default (``--default true --closed-value false``); a
``_DISABLED``-style kill switch is ``--default false --closed-value true``.

Failure posture: fail **open**. If the ``.env`` cannot be read for any reason,
warn on stderr and exit 0 rather than silently disabling the caller. A broken
gate that stops an agent from ever waking again is a worse outcome than one that
ignores an opt-out. Note that the cadence check this order chains after the gate
takes the opposite posture, and its docstring says why.

No network, no credentials, pure stdlib.
"""

import argparse
import os
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent

__all__ = ["env_file_candidates", "find_factory_root", "parse_env_file", "resolve", "main"]

# An on-by-default gate: absent configuration means "run", and only the literal
# `false` turns it off. Matches the shell test these gates used to inline.
DEFAULT_VALUE = "true"
CLOSED_VALUE = "false"

EXIT_OPEN = 0
EXIT_CLOSED = 1


def find_factory_root(start):
    """Walk up from ``start`` looking for a directory containing ``city.toml``."""
    current = Path(start).resolve()
    for candidate in [current, *current.parents]:
        if (candidate / "city.toml").exists():
            return candidate
    return None


def parse_env_file(path):
    """Parse a shell-style ``.env`` file into a dict.

    Skips blank lines and ``#`` comments, strips a leading ``export ``, peels one
    layer of matching single or double quotes off the value, and drops a trailing
    inline comment. Lines without an ``=`` are ignored.
    """
    out = {}
    for raw in Path(path).read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export "):]
        if "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip()
        if value[:1] in ("'", '"'):
            quote = value[0]
            end = value.find(quote, 1)
            if end != -1:
                value = value[1:end]
        else:
            # A `#` only opens a comment when whitespace precedes it, so a value
            # that starts with one — a channel name like `#ops` — survives whole.
            cuts = [c for c in (value.find(" #"), value.find("\t#")) if c != -1]
            if cuts:
                value = value[:min(cuts)].rstrip()
        out[key] = value
    return out


def env_file_candidates():
    """Return candidate ``.env`` paths in precedence order, de-duplicated.

    ``$FACTORY_ROOT`` first so an operator who points the factory somewhere
    unusual keeps control, then ``$GC_CITY_PATH``, then the cwd, then the
    nearest ``city.toml`` ancestor of the cwd and of this script.

    De-duplication is by resolved path, keeping the first occurrence so
    precedence wins. Paths are returned whether or not they exist; the caller
    skips missing ones.
    """
    paths = []
    for var in ("FACTORY_ROOT", "GC_CITY_PATH"):
        root = os.environ.get(var, "").strip()
        if root:
            paths.append(Path(root) / ".env")
    paths.append(Path.cwd() / ".env")
    for start in (Path.cwd(), _HERE):
        inferred = find_factory_root(start)
        if inferred is not None:
            paths.append(inferred / ".env")

    seen = set()
    deduped = []
    for path in paths:
        try:
            resolved = path.resolve()
        except OSError:
            continue
        if resolved in seen:
            continue
        seen.add(resolved)
        deduped.append(path)
    return deduped


def resolve(name, default=DEFAULT_VALUE):
    """Resolve ``name`` to ``(value, source)``.

    ``source`` is ``"environment"``, the ``.env`` path the value came from, or
    ``"default"``. It exists so the caller can tell the operator *why* a gate is
    closed, which is the question they ask the moment one is.

    An empty value is treated as absent at every layer, mirroring the shell's
    ``${VAR:-default}`` behaviour.
    """
    direct = os.environ.get(name)
    if direct:
        return direct, "environment"

    for path in env_file_candidates():
        try:
            if not path.is_file():
                continue
            values = parse_env_file(path)
        except OSError:
            # An unreadable .env is not a reason to shut the gate — keep looking.
            continue
        value = values.get(name)
        if value:
            return value, str(path)

    return default, "default"


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="order_env_gate.py",
        description=(
            "Exit 0 when an order's environment gate is open, 1 when the "
            "operator has closed it in $FACTORY_ROOT/.env."
        ),
    )
    parser.add_argument("name", help="Gate variable, e.g. DAILY_INTROSPECT.")
    parser.add_argument(
        "--default",
        default=DEFAULT_VALUE,
        help="Value to assume when nothing sets the variable (default: %(default)s).",
    )
    parser.add_argument(
        "--closed-value",
        default=CLOSED_VALUE,
        help=(
            "Value that closes the gate (default: %(default)s). Use "
            "`--default false --closed-value true` for a _DISABLED-style kill switch."
        ),
    )
    args = parser.parse_args(argv)

    try:
        value, source = resolve(args.name, args.default)
    except Exception as exc:  # noqa: BLE001 — fail open, never strand the caller
        print(
            "order_env_gate: could not resolve {} ({}); leaving the gate open".format(args.name, exc),
            file=sys.stderr,
        )
        return EXIT_OPEN

    if value == args.closed_value:
        print("order_env_gate: {}={} (from {}); gate closed, skipping".format(args.name, value, source))
        return EXIT_CLOSED
    return EXIT_OPEN


if __name__ == "__main__":
    sys.exit(main())
