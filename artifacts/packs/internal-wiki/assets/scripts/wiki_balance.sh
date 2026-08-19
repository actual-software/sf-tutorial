#!/usr/bin/env bash
# wiki_balance.sh — one line per firing: how much the factory read the wiki,
# how much it wrote, and how long since anyone added a page. Fired hourly by
# orders/wiki-balance.toml.
#
# A wiki fails in two directions and the pair of numbers tells you which one you
# have. Reads near zero means a filing cabinet nobody opens, and the fix is in
# the agents' prompts. Writes near zero with healthy reads means it is going
# stale, and the fix is at the end of a task rather than the start.
set -euo pipefail

CITY="${GC_STORE_ROOT:-${FACTORY_PATH:-${GC_CITY_PATH:-}}}"
[ -n "$CITY" ] || { echo "wiki_balance.sh: no GC_STORE_ROOT, FACTORY_PATH or GC_CITY_PATH to resolve the city" >&2; exit 2; }

WIKI="${TEAM_WIKI_PATH:-$CITY/team-wiki}"
LOG="${WIKI_ACCESS_LOG:-$CITY/wiki-access.jsonl}"
OUT="$CITY/WIKI_LOG.md"

if [ ! -s "$OUT" ]; then
    cat > "$OUT" <<'HEADER'
# Wiki log

Written hourly by the `wiki-balance` order in the `internal-wiki` pack. Each
line is the running total of reads and writes against the team wiki, plus how
long it has been since anyone added a page. Subtract two lines to get the
balance for the hours between them.

Reads near zero means nobody is consulting the wiki, so the factory is still
re-deriving what it already knows. Writes near zero means nothing new is going
in. Both are worth noticing, and neither shows up anywhere else.

HEADER
fi

count_op() {
    [ -s "$LOG" ] || { printf '0'; return 0; }
    jq -r --arg op "$1" 'select(.op == $op) | .op' "$LOG" 2>/dev/null | wc -l | tr -d ' '
}

READS=$(( $(count_op search) + $(count_op read) + $(count_op list) ))
WRITES="$(count_op write)"

if [ -d "$WIKI/.git" ]; then
    PAGES="$(cd "$WIKI" && git ls-files '*.md' | wc -l | tr -d ' ')"
    # The newest commit stands in for the newest page: every write goes through
    # `wiki.sh write`, which commits, so the two move together.
    LAST="$(cd "$WIKI" && git log -1 --format=%cr 2>/dev/null || printf 'never')"
else
    PAGES=0
    LAST="no wiki yet"
fi

LINE="- balance $(date -u '+%Y-%m-%dT%H:%MZ') — reads $READS, writes $WRITES, pages $PAGES, newest page $LAST"
printf '%s\n' "$LINE" >> "$OUT"
printf '%s\n' "$LINE"
