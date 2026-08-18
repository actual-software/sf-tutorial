#!/usr/bin/env bash
# Append every closed bead that is not in the log yet. Fired by
# orders/bead-closed-log.toml on each `bead.closed` event.
#
# The skip-what-is-already-there test is doing two jobs. One firing can stand
# for several closes, because the event cursor advances past all of them at
# once. And `gc order run bead-closed-log` is the natural way to try this by
# hand, which would otherwise write the same beads again every time.
set -euo pipefail

. "$(dirname "$0")/factory_log.sh"

LOG="$(factory_log_path)"
factory_log_init "$LOG"

# `|| true` covers the whole pipeline, so a momentarily unavailable bd leaves
# this firing empty-handed rather than failing the order.
ROWS="$(bd list --status closed --limit 0 --json 2>/dev/null \
        | jq -r '.[] | "\(.id)\t\(.title)"' 2>/dev/null || true)"
[ -n "$ROWS" ] || exit 0

STAMP="$(date -u '+%Y-%m-%dT%H:%MZ')"

while IFS=$'\t' read -r id title; do
    [ -n "$id" ] || continue
    grep -qF -- "[$id]" "$LOG" && continue
    printf -- '- closed %s [%s] %s\n' "$STAMP" "$id" "$title" >> "$LOG"
done <<< "$ROWS"
