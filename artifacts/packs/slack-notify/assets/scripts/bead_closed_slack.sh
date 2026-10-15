#!/usr/bin/env bash
# Post each piece of work the rig closes to a Slack channel, through an incoming
# webhook. Fired by orders/bead-closed-slack.toml on each `bead.closed` event.
#
# Same skeleton as base-factory's bead_closed_log.sh: the event wakes the script
# without saying which bead closed, so it asks bd what is closed and skips what
# it has already sent. A post to a shared channel costs more than a line in a
# log nobody reads, so four things sit on top of that skeleton:
#
#   a filter     formula steps and wisps close too, several per sling. Only
#                work items post: the beads you created or slung, not the
#                plumbing.
#   a baseline   the first run records what is already closed and posts none of
#                it, so installing on a busy factory does not replay its history.
#   a burst cap  more than BURST_MAX new closes in one firing become a single
#                summary message, so a burst costs one webhook call.
#   a secret     the webhook URL lets anyone who holds it post to your channel.
#                It is read from .env, handed to curl on stdin rather than on the
#                command line, and never printed.
#
# Needs bash, curl, jq and bd, and nothing else.
set -uo pipefail

BURST_MAX=5             # more new closes than this in one firing: one summary
SUMMARY_LINES=20        # beads listed in a summary before "...and N more"
WORK_TYPES='["task","bug","feature","chore","epic"]'

# ── 1. The webhook URL ────────────────────────────────────────────────────
# An exec order is handed the controller's environment, and the city's .env is
# never loaded into it, so the script reads the file itself. Process environment
# wins over the file, the same rule the self-improvement pack's gate follows.
# No URL means the pack is installed but switched off: exit quietly.
ENV_FILE="${FACTORY_ROOT:-${GC_CITY_PATH:-.}}/.env"
if [ -z "${SLACK_WEBHOOK_URL:-}" ] && [ -r "$ENV_FILE" ]; then
    line="$(grep -E '^[[:space:]]*(export[[:space:]]+)?SLACK_WEBHOOK_URL=' "$ENV_FILE" | tail -n 1)"
    line="${line#*=}"
    # Cut at the first space, which drops a trailing comment or a Windows \r, then strip quotes.
    SLACK_WEBHOOK_URL="$(printf '%s' "${line%%[[:space:]]*}" | tr -d "\"'")"
fi
[ -n "${SLACK_WEBHOOK_URL:-}" ] || exit 0

case "$SLACK_WEBHOOK_URL" in
    https://*|http://*) ;;
    *) echo "slack-notify: SLACK_WEBHOOK_URL is set but is not a URL; nothing sent" >&2
       exit 1 ;;
esac

# ── 2. Where this rig's sent list lives ───────────────────────────────────
# GC_PACK_STATE_DIR is the controller's per-pack directory under the city's
# .gc/runtime, which keeps the list out of the rig's git checkout. One pack can
# be imported on several rigs, so each rig gets its own list.
STATE_DIR="${GC_PACK_STATE_DIR:-${GC_CITY_PATH:-.}/.gc/runtime/packs/slack-notify}/${GC_RIG:-city}"
SENT="$STATE_DIR/sent"
mkdir -p "$STATE_DIR" || exit 1

# A firing by hand can overlap one the controller started for the same close,
# and both would post it. mkdir is atomic, so it is the lock. A firing killed at
# its timeout never reaches the trap, so a lock older than two minutes is stale.
LOCK="$STATE_DIR/lock"
find "$LOCK" -maxdepth 0 -mmin +2 -exec rmdir {} \; 2>/dev/null
if ! mkdir "$LOCK" 2>/dev/null; then
    echo "slack-notify: another firing is running; leaving the beads to it"
    exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# ── 3. Closed work items ──────────────────────────────────────────────────
# A failed read must not reach the baseline below: an empty baseline would make
# the next firing post the rig's entire history.
if ! CLOSED="$(bd list --status closed --limit 0 --json 2>/dev/null)"; then
    echo "slack-notify: bd list failed; nothing sent, nothing recorded" >&2
    exit 1
fi
WORK="$(printf '%s' "$CLOSED" | jq -c --argjson types "$WORK_TYPES" '
    (if type == "object" then (.data // []) else . end)
    | map(select(.issue_type as $t | $types | index($t)))
    | map(select((.metadata // {})
                 | (has("gc.kind") or has("gc.step_id") or has("gc.step_ref")
                    or has("gc.root_bead_id")) | not))
    | map(select(.id | test("-wisp-") | not))
    | sort_by(.closed_at // "")
    | map({id, title: (.title // ""), pr: (.metadata.pr_url // "")})')" \
    || { echo "slack-notify: could not parse bd output; nothing sent" >&2; exit 1; }

if [ ! -f "$SENT" ]; then
    printf '%s' "$WORK" | jq -r '.[].id' > "$SENT.tmp" && mv "$SENT.tmp" "$SENT" || exit 1
    echo "slack-notify: first run on ${GC_RIG:-this scope}: $(grep -c . "$SENT") closed bead(s) recorded as already seen, none posted"
    exit 0
fi

NEW="$(printf '%s' "$WORK" | jq -c --rawfile sent "$SENT" '
    ($sent | split("\n") | map(select(length > 0) | {(.): true}) | add // {}) as $done
    | map(select($done[.id] | not))')" \
    || { echo "slack-notify: could not read the sent list; nothing sent" >&2; exit 1; }
COUNT="$(printf '%s' "$NEW" | jq 'length')"
[ "$COUNT" -gt 0 ] || exit 0

# ── 4. The messages ───────────────────────────────────────────────────────
# One per bead, or one summary for a burst. Each carries the ids it covers, so
# an id is recorded as sent only once Slack has accepted the message naming it.
MESSAGES="$(printf '%s' "$NEW" | jq -c \
    --arg rig "${GC_RIG:-the factory}" --argjson max "$BURST_MAX" --argjson lines "$SUMMARY_LINES" '
    def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
    def pr:  if .pr == "" then ""
             else " · <\(.pr)|PR #\((.pr | capture("/pull/(?<n>[0-9]+)").n) // "link")>" end;
    def item: "`\(.id)` \(.title | esc)\(pr)";
    if length <= $max then
        map({ids: [.id], text: ":white_check_mark: Closed on *\($rig)*: \(item)"})
    else
        [{ids: map(.id),
          text: ([":white_check_mark: *\($rig)* closed \(length) beads:"]
                 + (.[:$lines] | map("• \(item)"))
                 + (if length > $lines then ["…and \(length - $lines) more"] else [] end)
                 | join("\n"))}]
    end')"

# The URL goes to curl as a config line on stdin, so it never appears in an
# argument list that `ps` can show. Each call is capped well under the order's
# 60s timeout, so a Slack outage costs one slow firing rather than a hung one.
post() {
    curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 8 \
         -H 'Content-Type: application/json' --data-binary "$1" \
         -K - <<< "url = \"$SLACK_WEBHOOK_URL\""
}

POSTED=0
SENT_MESSAGES=0
while IFS= read -r msg; do
    [ "$SENT_MESSAGES" -eq 0 ] || sleep 1      # Slack allows one post a second
    ids="$(printf '%s' "$msg" | jq -r '.ids | join(" ")')"
    code="$(post "$(printf '%s' "$msg" | jq -c '{text}')")"
    if [ "$code" != "200" ]; then
        echo "slack-notify: posting $ids failed (HTTP ${code:-000}, where 000 means no answer); the next firing retries it" >&2
        exit 1
    fi
    printf '%s' "$msg" | jq -r '.ids[]' >> "$SENT"
    POSTED=$(( POSTED + $(printf '%s' "$msg" | jq '.ids | length') ))
    SENT_MESSAGES=$(( SENT_MESSAGES + 1 ))
done < <(printf '%s' "$MESSAGES" | jq -c '.[]')

echo "slack-notify: posted $POSTED closed bead(s) from ${GC_RIG:-this scope} in $SENT_MESSAGES message(s)"
