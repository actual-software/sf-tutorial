#!/bin/sh
# gc slack reply-current: answer a Slack mention through slack-mini.
#
# When a mention reaches a session, gc's reminder tells the agent to reply with
# `gc slack reply-current --conversation-id <channel> --body-file <path>`.
# slack-mini ships one outbound verb, post-message, and no reply-current, so
# this command takes the reminder's flags and hands them to that verb.
set -eu

usage() {
  cat "$(dirname "$0")/reply-current/help.md"
}

conversation=""
body=""
body_file=""
thread_ts=""

need_value() {
  if [ "$2" -lt 2 ]; then
    echo "gc slack reply-current: $1 requires a value" >&2
    exit 2
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --conversation-id) need_value "$1" "$#"; conversation="$2"; shift 2 ;;
    --body)            need_value "$1" "$#"; body="$2"; shift 2 ;;
    --body-file)       need_value "$1" "$#"; body_file="$2"; shift 2 ;;
    --reply-to|--thread-ts) need_value "$1" "$#"; thread_ts="$2"; shift 2 ;;
    --conversation-id=*) conversation="${1#*=}"; shift ;;
    --body=*)            body="${1#*=}"; shift ;;
    --body-file=*)       body_file="${1#*=}"; shift ;;
    --reply-to=*|--thread-ts=*) thread_ts="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "gc slack reply-current: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "$conversation" ]; then
  echo "gc slack reply-current: --conversation-id is required (the Slack channel id from the message)" >&2
  exit 2
fi
if [ -n "$body" ] && [ -n "$body_file" ]; then
  echo "gc slack reply-current: give --body or --body-file, not both" >&2
  exit 2
fi
if [ -n "$body_file" ]; then
  if [ ! -f "$body_file" ] || [ ! -r "$body_file" ]; then
    echo "gc slack reply-current: cannot read $body_file" >&2
    exit 2
  fi
  body=$(cat "$body_file")
fi
if [ -z "$body" ]; then
  echo "gc slack reply-current: the reply is empty" >&2
  exit 2
fi

# post-message reaches the adapter through the supervisor's API, and falls back
# to a port the supervisor does not use. Point it at the supervisor's own port
# unless the caller already did.
if [ -z "${GC_API_BASE_URL:-}" ]; then
  port=$(sed -n 's/^[[:space:]]*port[[:space:]]*=[[:space:]]*\([0-9][0-9]*\).*/\1/p' \
    "${GC_HOME:-$HOME/.gc}/supervisor.toml" 2>/dev/null | head -n 1)
  GC_API_BASE_URL="http://127.0.0.1:${port:-8372}"
  export GC_API_BASE_URL
fi

if [ -n "$thread_ts" ]; then
  exec "${GC_BIN:-gc}" slack-mini post-message --channel "$conversation" --thread-ts "$thread_ts" --text "$body"
fi
exec "${GC_BIN:-gc}" slack-mini post-message --channel "$conversation" --text "$body"
