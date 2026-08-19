#!/usr/bin/env bash
# wiki.sh — the one entry point for team-wiki access.
#
# Every subcommand appends one line to the access log before it returns, which
# is the whole reason the helper exists. A wiki is a directory, and `grep` and
# `cat` would read it perfectly well; what they cannot do is tell you afterwards
# whether anyone read it. Route access through one command and the answer is a
# file you can count.
#
# The log write is best-effort on purpose. A failed append warns and the read
# still returns its content, because an agent that cannot log is still an agent
# that needs the page.
set -euo pipefail

usage() {
    cat <<'USAGE'
usage: wiki.sh <command> [args]

  setup [<city-root>]  create the wiki and drop a pointer to this helper
                       in the city root, so agents can find it by one path
  search <pattern>     grep the wiki (exit 1 on no match, like grep)
  read <path>          print one page
  write <path>         write a page from stdin and commit it
  list [<path>]        list pages
  log                  print the access log

The wiki lives at $TEAM_WIKI_PATH, defaulting to team-wiki inside the city.
USAGE
}

# ── Paths ─────────────────────────────────────────────────────────────
# Three contexts run this script and each one sets a different variable.
# GC_STORE_ROOT comes from the controller for both rig- and city-scoped orders.
# GC_CITY_PATH is what an agent session has. FACTORY_PATH is what a participant
# has in their own shell. `setup` also accepts the root as an argument, which is
# how the agents' pre_start passes {{.CityRoot}} before any of the three is
# guaranteed to be there.
#
# Resolving to empty is a real state rather than an error, because `setup` has
# to survive it: a pre_start that exits non-zero is a pre_start that stops the
# agent from starting.
CITY="${GC_STORE_ROOT:-${FACTORY_PATH:-${GC_CITY_PATH:-}}}"
WIKI="${TEAM_WIKI_PATH:-${CITY:+$CITY/team-wiki}}"
LOG="${WIKI_ACCESS_LOG:-${CITY:+$CITY/wiki-access.jsonl}}"

require_city() {
    [ -n "$WIKI" ] || {
        echo "wiki.sh: set TEAM_WIKI_PATH, or run this where GC_STORE_ROOT, FACTORY_PATH or GC_CITY_PATH is set" >&2
        exit 2
    }
}

# ── The log ───────────────────────────────────────────────────────────
# One compact JSON object per line. `agent` is whoever ran the command, which
# is an agent's own name when the factory did it and your shell user when you
# did it by hand; both are worth telling apart when you read the balance.
log_event() {
    local op="$1" target="${2-}" query="${3-}" hits="${4-}"
    command -v jq >/dev/null 2>&1 || {
        echo "wiki.sh: jq is not installed, so this access went unlogged" >&2
        return 0
    }
    jq -nc \
        --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        --arg agent "${GC_AGENT:-${USER:-unknown}}" \
        --arg op "$op" --arg target "$target" --arg query "$query" --arg hits "$hits" \
        '{ts: $ts, agent: $agent, op: $op}
         + (if $target == "" then {} else {target: $target} end)
         + (if $query  == "" then {} else {query: $query}   end)
         + (if $hits   == "" then {} else {hits: ($hits | tonumber)} end)' \
        >> "$LOG" 2>/dev/null \
        || echo "wiki.sh: could not append to $LOG, so this access went unlogged" >&2
}

require_wiki() {
    require_city
    [ -d "$WIKI/.git" ] || {
        echo "wiki.sh: no wiki at $WIKI — run 'wiki.sh setup' first" >&2
        exit 2
    }
}

# ── Commands ──────────────────────────────────────────────────────────
# Runs from the agents' pre_start as well as by hand, so it never fails: an
# agent that cannot get a wiki should still start, and the helper says what is
# missing when the agent reaches for it.
cmd_setup() {
    local root="${1:-$CITY}"
    [ -n "$WIKI" ] || WIKI="${root:+$root/team-wiki}"
    [ -n "$LOG" ] || LOG="${root:+$root/wiki-access.jsonl}"
    if [ -z "$WIKI" ]; then
        echo "wiki.sh: no city root to hang the wiki off, so nothing was created" >&2
        return 0
    fi
    if [ ! -d "$WIKI/.git" ]; then
        seed_wiki || echo "wiki.sh: could not create the wiki at $WIKI" >&2
    fi
    # The prompt fragment calls the helper as <city-root>/wiki.sh, because a
    # prompt template can resolve the city root and cannot reach the pack
    # directory this script actually lives in. The symlink closes that gap, and
    # `ls -l` on it shows where the real script is.
    if [ -n "$root" ] && [ -d "$root" ]; then
        ln -sfn "$(cd "$(dirname "$0")" && pwd)/$(basename "$0")" "$root/wiki.sh" \
            || echo "wiki.sh: could not link $root/wiki.sh" >&2
    fi
    return 0
}

seed_wiki() {
    mkdir -p "$WIKI"
    git -C "$WIKI" init --quiet
    cat > "$WIKI/README.md" <<'SEED'
# Team wiki

Durable findings, written once and read by everyone after.

A page belongs here when a colleague hitting the same thing in six months would
save time by reading it: a non-obvious failure mode and its workaround, an
incident and how it was found, a decision and the reasoning behind it. Anything
that only matters to the work in flight belongs on the bead instead.

Write pages through `wiki.sh` rather than your editor, so every read and write
lands in the access log and the factory can tell a wiki people use from a
directory nobody opens.
SEED
    git -C "$WIKI" add README.md
    git -C "$WIKI" -c user.email=wiki@localhost -c user.name="team wiki" \
        commit --quiet -m "Start the team wiki"
    echo "Created $WIKI"
}

cmd_search() {
    require_wiki
    [ $# -ge 1 ] || { usage >&2; exit 2; }
    local pattern="$1"; shift
    local out rc=0
    # Run from inside the wiki so hits come back as wiki-relative paths, which
    # is what `wiki.sh read` takes.
    out="$(cd "$WIKI" && grep -rn --exclude-dir=.git -- "$pattern" . 2>/dev/null | sed 's|^\./||')" || rc=$?
    local hits=0
    [ -n "$out" ] && hits="$(printf '%s\n' "$out" | wc -l | tr -d ' ')"
    log_event search "" "$pattern" "$hits"
    [ -n "$out" ] && printf '%s\n' "$out"
    return "$rc"
}

cmd_read() {
    require_wiki
    [ $# -eq 1 ] || { usage >&2; exit 2; }
    local rel="$1"
    [ -f "$WIKI/$rel" ] || { echo "wiki.sh: no page at $rel" >&2; exit 1; }
    log_event read "$rel"
    cat "$WIKI/$rel"
}

cmd_write() {
    require_wiki
    [ $# -eq 1 ] || { usage >&2; exit 2; }
    local rel="$1"
    mkdir -p "$(dirname "$WIKI/$rel")"
    cat > "$WIKI/$rel"
    git -C "$WIKI" add -- "$rel"
    # Nothing staged means the body matched what was already there, which is a
    # real outcome rather than an error: two agents can reach the same finding.
    if git -C "$WIKI" diff --cached --quiet -- "$rel"; then
        log_event write "$rel"
        echo "No change to $rel"
        return 0
    fi
    git -C "$WIKI" -c user.email=wiki@localhost -c user.name="team wiki" \
        commit --quiet -m "Update $rel"
    log_event write "$rel"
    echo "Wrote $rel"
}

cmd_list() {
    require_wiki
    local rel="${1-}"
    log_event list "$rel"
    ( cd "$WIKI" && git ls-files -- "${rel:-.}" )
}

cmd_log() {
    # Reading the log is not wiki access, so this one does not log itself.
    require_city
    [ -f "$LOG" ] && cat "$LOG" || echo "No access log yet at $LOG" >&2
}

case "${1-}" in
    setup)  shift; cmd_setup "$@" ;;
    search) shift; cmd_search "$@" ;;
    read)   shift; cmd_read "$@" ;;
    write)  shift; cmd_write "$@" ;;
    list)   shift; cmd_list "$@" ;;
    log)    shift; cmd_log "$@" ;;
    -h|--help|help) usage ;;
    *)      usage >&2; exit 2 ;;
esac
