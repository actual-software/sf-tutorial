#!/usr/bin/env bash
# One line per firing: how many beads are open, in progress and closed right
# now. Fired hourly by orders/factory-pulse.toml.
set -euo pipefail

. "$(dirname "$0")/factory_log.sh"

LOG="$(factory_log_path)"
factory_log_init "$LOG"

# bd resolves its database from the environment the controller hands the order,
# so this runs against the rig's beads without a cd. `--limit 0` lifts the
# result cap; without it a busy board reports its cap rather than its size.
count() {
    bd list --status "$1" --limit 0 --json 2>/dev/null | jq 'length' 2>/dev/null || printf '?'
}

printf -- '- pulse %s — open %s, in progress %s, closed %s\n' \
    "$(date -u '+%Y-%m-%dT%H:%MZ')" \
    "$(count open)" "$(count in_progress)" "$(count closed)" \
    >> "$LOG"
