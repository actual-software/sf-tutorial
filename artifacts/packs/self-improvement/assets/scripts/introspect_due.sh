#!/usr/bin/env bash
# Answer one question for the `daily-introspect` order: should a pass run now?
#
# Two things have to be true, and the order's `check` line calls this script for
# both because a trigger cannot ask for both itself. Trigger evaluation is a
# switch on the trigger type, so exactly one branch runs: a `cooldown` order
# never consults `check`, and a `condition` order never consults `interval`. You
# cannot compose an interval with an environment gate by declaring both fields. A
# condition check is a shell command, though, so it can evaluate the two together.
#
# NO `set -e` HERE, on purpose. This script's exit status is its answer, so an
# ordinary non-zero test is a result rather than a failure to abort on.
set -uo pipefail

VAR="${1:-DAILY_INTROSPECT}"
INTERVAL_HOURS="${2:-24}"
TITLE="daily introspection (state)"

# ── 1. The environment gate ───────────────────────────────────────────────
# The controller runs a check line with its own environment, and the city's
# .env is never loaded into it. So an inline `test "$DAILY_INTROSPECT" != false`
# reads an unset variable on every tick and the on-by-default branch always
# wins: the documented opt-out gets no error and no effect. Reading the file
# here is what makes it actually work. Process environment wins over the file,
# so an operator who exported the knob before starting the city still wins.
ENV_FILE="${FACTORY_ROOT:-${GC_CITY_PATH:-.}}/.env"
if [ -n "${!VAR:-}" ]; then
    [ "${!VAR}" = "false" ] && exit 1
elif grep -qE "^[[:space:]]*(export[[:space:]]+)?${VAR}=[\"']?false[\"']?[[:space:]]*(#.*)?\$" "$ENV_FILE" 2>/dev/null; then
    exit 1
fi

# ── 2. The cadence ────────────────────────────────────────────────────────
# Read from the last completed pass, not the last dispatch. A cooldown clock
# resets when the order fires, so a tick that dispatched but produced no pass
# still advances the schedule and the work stops without anything reporting an
# error. The pass stamps `last_pass_at` on its state bead when it finishes, and
# that is the clock this reads.
#
# FAIL CLOSED on anything unreadable. A condition check runs on every controller
# tick, so failing open does not run the pass once, it runs it on every tick
# until somebody notices. A pass that is a day late costs far less than that.
LAST="$(bd list --status open,in_progress --limit 0 --json 2>/dev/null \
        | jq -r --arg t "$TITLE" \
          '[.[] | select(.title == $t)] | last | .metadata.last_pass_at // .created_at // empty' 2>/dev/null)" \
    || { echo "introspect_due: could not read the bead store; treating the pass as not due" >&2; exit 1; }

# No state bead means no pass has ever run, so the first one is due.
[ -z "$LAST" ] && exit 0

# Falling back to created_at above matters on the tick after a pass crashed
# before stamping itself: without it the check reads "never ran" and dispatches
# again immediately, and again on the tick after that.
LAST_EPOCH="$(date -u -d "$LAST" +%s 2>/dev/null)"
[ -n "$LAST_EPOCH" ] \
    || { echo "introspect_due: unreadable timestamp '$LAST'; treating the pass as not due" >&2; exit 1; }

if [ "$(( $(date -u +%s) - LAST_EPOCH ))" -ge "$(( INTERVAL_HOURS * 3600 ))" ]; then
    exit 0
fi
echo "introspect_due: last pass $LAST, less than ${INTERVAL_HOURS}h ago; not due" >&2
exit 1
