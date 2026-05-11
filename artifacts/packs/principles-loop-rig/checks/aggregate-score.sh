#!/usr/bin/env bash
#
# aggregate-score.sh — read a per-bead principles YAML, compute
# latest-row-wins aggregate, exit 0 (PASS), 1 (CONTINUE), or 2
# (ESCALATE). Used by `mol-principles-review`.
#
# Usage:
#   aggregate-score.sh <yaml-path> [--target=0.9] [--min-per-principle=3]
#
# Exit codes:
#   0  PASS:     aggregate >= target AND every principle's latest score >= floor
#   1  CONTINUE: aggregate < target OR at least one floor < min-per-principle
#   2  ESCALATE: YAML malformed, missing principle, principle name not in canonical 23

set -uo pipefail

YAML="${1:-}"
TARGET=0.9
MIN_PER_PRINCIPLE=3

shift || true
for arg in "$@"; do
  case "$arg" in
    --target=*)            TARGET="${arg#*=}" ;;
    --min-per-principle=*) MIN_PER_PRINCIPLE="${arg#*=}" ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

if [ -z "$YAML" ]; then
  echo "usage: aggregate-score.sh <yaml-path> [--target=0.9] [--min-per-principle=3]" >&2
  exit 2
fi

if ! [ -f "$YAML" ]; then
  echo "yaml not found: $YAML" >&2
  exit 2
fi

if ! python3 -c 'import yaml' 2>/dev/null; then
  echo "PyYAML missing — run: python3 -m pip install pyyaml" >&2
  exit 2
fi

python3 - "$YAML" "$TARGET" "$MIN_PER_PRINCIPLE" <<'PY'
import sys
import yaml

# Canonical 23 — keep byte-identical with the formula's principle list.
CANONICAL = [
    "Separation of Concerns",
    "Single Responsibility Principle",
    "DRY",
    "KISS",
    "YAGNI",
    "Loose Coupling",
    "High Cohesion",
    "Encapsulation",
    "Composition Over Inheritance",
    "Don't Swallow Errors",
    "Fail Fast",
    "Idempotence",
    "Pure Functions Where Possible",
    "Test-Driven Development",
    "Observability",
    "Defensive Programming",
    "Immutability",
    "Convention Over Configuration",
    "Principle of Least Astonishment",
    "Single Source of Truth",
    "Explicit is Better than Implicit",
    "Inversion of Control",
    "Domain-Driven Naming",
]
assert len(CANONICAL) == 23
CANON_SET = set(CANONICAL)

path, target_s, floor_s = sys.argv[1:]
target = float(target_s)
floor = float(floor_s)

with open(path) as f:
    rows = yaml.safe_load(f) or []

if not isinstance(rows, list):
    print("ESCALATE: top-level YAML must be a list", file=sys.stderr)
    sys.exit(2)

# Validate row shape and canonical names.
for i, r in enumerate(rows):
    if not isinstance(r, dict):
        print(f"ESCALATE: row {i} is not a mapping", file=sys.stderr)
        sys.exit(2)
    for k in ("principle", "iteration", "score", "timestamp"):
        if k not in r:
            print(f"ESCALATE: row {i} missing key {k}", file=sys.stderr)
            sys.exit(2)
    if r["principle"] not in CANON_SET:
        print(f"ESCALATE: principle not in canonical 23: {r['principle']!r}", file=sys.stderr)
        sys.exit(2)

# Latest-row-wins per (principle).
latest = {}
for r in rows:
    p = r["principle"]
    prev = latest.get(p)
    if prev is None or r["timestamp"] > prev["timestamp"]:
        latest[p] = r

# Detect duplicate-timestamp ambiguity.
ts_counts = {}
for r in rows:
    key = (r["principle"], r["timestamp"])
    ts_counts[key] = ts_counts.get(key, 0) + 1
for (p, t), c in ts_counts.items():
    if c > 1:
        print(f"ESCALATE: duplicate row for principle={p} at timestamp={t}", file=sys.stderr)
        sys.exit(2)

# Missing principles count as 0 (cannot pass with partial coverage).
scores = [latest.get(p, {"score": 0})["score"] for p in CANONICAL]
agg = sum(scores) / (5.0 * 23.0)
lowest = sorted(
    ((p, latest.get(p, {"score": 0})["score"]) for p in CANONICAL),
    key=lambda kv: kv[1],
)[:3]

decision = "PASS" if (agg >= target and all(s >= floor for s in scores)) else "CONTINUE"
import json
print(json.dumps({
    "aggregate": round(agg, 4),
    "target": target,
    "lowest": [{"principle": p, "score": s} for p, s in lowest],
    "decision": decision,
}))
print(f"aggregate={agg:.4f} target={target} decision={decision}", file=sys.stderr)

sys.exit(0 if decision == "PASS" else 1)
PY
