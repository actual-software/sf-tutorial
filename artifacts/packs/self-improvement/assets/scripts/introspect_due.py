#!/usr/bin/env python3
"""Decide whether the daily introspection pass is due, from the last *pass*
rather than the last dispatch.

Why this exists
---------------
The obvious way to schedule a daily pass is a cooldown trigger: fire every 24
hours and let the agent take it from there. That clock measures the wrong thing.
A cooldown order's tracking record closes the moment the order dispatches, so
the next window opens 24 hours after the *dispatch* whether or not a pass
actually happened. Miss one and the schedule keeps its rhythm while the work
silently stops.

That is not hypothetical. On the factory this pack was carved from, the order
fired on a clean 24-hour cadence for five days while the state record showed the
last completed pass finishing five and a half hours *before* the most recent
firing. The two clocks had drifted apart: one firing produced no pass, and one
pass had no firing behind it. Nothing reported an error, because from the
order's point of view every tick went fine.

This check closes that gap by reading the timestamp the pass itself writes when
it finishes. The window opens relative to the last completed pass, so a pass
that does not happen does not advance the clock.

It also carries the environment gate's cadence half, and that pairing is
deliberate rather than a workaround. Trigger evaluation picks exactly one
branch by trigger type, so a `condition` order never consults an interval and a
`cooldown` order never consults a check. An order cannot compose a 24-hour
interval with an environment gate by declaring both. A condition check *is* a
shell command, though, so it can evaluate the gate and the cadence together —
which is what the order does, chaining this script after the gate with `&&`.

Contract
--------
``introspect_due.py [--interval 24h] [--title TITLE] [--now ISO8601]``

Exit 0
    Due. The interval has elapsed since the last completed pass, or no pass has
    ever run. The caller should proceed.
Exit 1
    Not due, or the answer could not be determined.

Failure posture: fail **closed**, which is the opposite of what an environment
gate should do and for a concrete reason. A condition trigger is evaluated on
every controller tick, so a check that fails open does not run the pass once —
it runs it on every tick until somebody notices. An audit that is a day late
costs far less than a dispatch storm.

Finding the state record
------------------------
The pass keeps one singleton bead titled ``daily introspection (state)`` and
stamps ``last_pass_at`` on it when it finishes. This script finds that bead by
title, so the title is a contract between the two rather than a label. Override
it with ``--title`` on both sides if you want a different one.

When the bead exists but carries no readable ``last_pass_at``, the bead's own
creation time is used instead. That matters on the tick right after a pass
crashed before stamping its state: without the fallback the check would read
"never ran" and dispatch again immediately, and again on the tick after that.

No network, no credentials, pure stdlib.
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone

DEFAULT_TITLE = "daily introspection (state)"
DEFAULT_INTERVAL = "24h"
PASS_FIELD = "last_pass_at"

EXIT_DUE = 0
EXIT_NOT_DUE = 1

_INTERVAL_RE = re.compile(r"^\s*(\d+(?:\.\d+)?)\s*([smhdw]?)\s*$", re.IGNORECASE)
_UNIT_SECONDS = {"s": 1, "m": 60, "h": 3600, "d": 86400, "w": 604800, "": 1}

# Tolerant of the shapes bd and hand-editing produce: a trailing Z or a numeric
# offset, a space or a T between date and time, and optional fractional seconds.
# datetime.fromisoformat alone rejects the Z form before Python 3.11.
_TS_RE = re.compile(
    r"^(?P<date>\d{4}-\d{2}-\d{2})[T ](?P<time>\d{2}:\d{2}(?::\d{2})?)"
    r"(?:\.\d+)?(?P<tz>Z|[+-]\d{2}:?\d{2})?$",
    re.IGNORECASE,
)


def parse_interval(text):
    """Turn ``24h`` / ``90m`` / ``3600`` into a timedelta. Raises ValueError."""
    match = _INTERVAL_RE.match(text)
    if not match:
        raise ValueError("expected a number with an optional s/m/h/d/w suffix, e.g. 24h")
    magnitude, unit = match.group(1), match.group(2).lower()
    seconds = float(magnitude) * _UNIT_SECONDS[unit]
    if seconds <= 0:
        raise ValueError("interval must be greater than zero")
    return timedelta(seconds=seconds)


def parse_timestamp(text):
    """Parse a UTC-ish timestamp into an aware datetime, or return None."""
    if not isinstance(text, str):
        return None
    match = _TS_RE.match(text.strip())
    if not match:
        return None
    time_part = match.group("time")
    if len(time_part) == 5:
        time_part += ":00"
    try:
        naive = datetime.strptime(match.group("date") + "T" + time_part, "%Y-%m-%dT%H:%M:%S")
    except ValueError:
        return None

    zone = match.group("tz")
    if zone is None or zone.upper() == "Z":
        return naive.replace(tzinfo=timezone.utc)
    zone = zone.replace(":", "")
    offset = timedelta(hours=int(zone[1:3]), minutes=int(zone[3:5]))
    return naive.replace(tzinfo=timezone(-offset if zone[0] == "-" else offset))


def load_state_bead(title):
    """Return the newest open bead with this exact title, or None.

    Raises RuntimeError if the store could not be read at all — the caller
    turns that into "not due" rather than guessing.
    """
    workdir = os.environ.get("GC_CITY_PATH", "").strip() or None
    try:
        completed = subprocess.run(
            ["bd", "list", "--status", "open,in_progress", "--limit", "0", "--json"],
            cwd=workdir,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=20,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        raise RuntimeError("could not run bd ({})".format(exc))

    if completed.returncode != 0:
        detail = completed.stderr.decode("utf-8", "replace").strip().splitlines()
        raise RuntimeError("bd list exited {} ({})".format(
            completed.returncode, detail[-1] if detail else "no output"))

    try:
        beads = json.loads(completed.stdout.decode("utf-8", "replace") or "[]")
    except ValueError as exc:
        raise RuntimeError("bd list did not return JSON ({})".format(exc))
    if not isinstance(beads, list):
        raise RuntimeError("bd list returned {}, expected a list".format(type(beads).__name__))

    matches = [b for b in beads if isinstance(b, dict) and (b.get("title") or "").strip() == title]
    if not matches:
        return None
    # Newest wins if a factory somehow ends up with two. Beads with an
    # unparseable created_at sort last rather than crashing the comparison.
    matches.sort(key=lambda b: (parse_timestamp(b.get("created_at")) or datetime.min.replace(tzinfo=timezone.utc)))
    return matches[-1]


def reference_time(bead):
    """When the last pass is believed to have completed, and where that came from."""
    metadata = bead.get("metadata")
    if isinstance(metadata, dict):
        stamped = parse_timestamp(metadata.get(PASS_FIELD))
        if stamped is not None:
            return stamped, PASS_FIELD
    created = parse_timestamp(bead.get("created_at"))
    if created is not None:
        return created, "created_at (no readable {})".format(PASS_FIELD)
    return None, "nothing readable on the state bead"


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="introspect_due.py",
        description="Exit 0 when the daily introspection pass is due, 1 when it is not.",
    )
    parser.add_argument("--interval", default=DEFAULT_INTERVAL,
                        help="How long after a completed pass the next one is due (default: %(default)s).")
    parser.add_argument("--title", default=DEFAULT_TITLE,
                        help="Title of the singleton state bead (default: %(default)s).")
    parser.add_argument("--now", default=None,
                        help="Override the current time, for testing. UTC ISO-8601.")
    parser.add_argument("--quiet", action="store_true", help="Suppress the one-line reason on stdout.")
    args = parser.parse_args(argv)

    def say(message):
        if not args.quiet:
            print("introspect_due: " + message)

    try:
        interval = parse_interval(args.interval)
    except ValueError as exc:
        print("introspect_due: bad --interval {!r}: {}".format(args.interval, exc), file=sys.stderr)
        return EXIT_NOT_DUE

    if args.now is None:
        now = datetime.now(timezone.utc)
    else:
        now = parse_timestamp(args.now)
        if now is None:
            print("introspect_due: bad --now {!r}".format(args.now), file=sys.stderr)
            return EXIT_NOT_DUE

    try:
        bead = load_state_bead(args.title)
    except RuntimeError as exc:
        # Fail closed. See the module docstring: a condition check runs every tick.
        print("introspect_due: {}; treating the pass as not due".format(exc), file=sys.stderr)
        return EXIT_NOT_DUE

    if bead is None:
        say("no state bead titled {!r}, so no pass has run yet; due".format(args.title))
        return EXIT_DUE

    last, source = reference_time(bead)
    if last is None:
        print("introspect_due: found the state bead but {}; treating the pass as not due".format(source),
              file=sys.stderr)
        return EXIT_NOT_DUE

    elapsed = now - last
    if elapsed >= interval:
        say("last pass {} ({}), {} ago; due".format(
            last.strftime("%Y-%m-%dT%H:%M:%SZ"), source, format_span(elapsed)))
        return EXIT_DUE

    say("last pass {} ({}), {} ago; next due in {}".format(
        last.strftime("%Y-%m-%dT%H:%M:%SZ"), source,
        format_span(elapsed), format_span(interval - elapsed)))
    return EXIT_NOT_DUE


def format_span(delta):
    total = int(delta.total_seconds())
    sign = "-" if total < 0 else ""
    total = abs(total)
    hours, remainder = divmod(total, 3600)
    return "{}{}h{:02d}m".format(sign, hours, remainder // 60)


if __name__ == "__main__":
    sys.exit(main())
