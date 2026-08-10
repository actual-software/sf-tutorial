#!/usr/bin/env bash
#
# Tests for sfbox. These cover the parts that run on your laptop with no box
# attached: local state, URL parsing, ssh config generation, and the decision
# half of the prompt-size guardrail.
#
#   ./tests/run-tests.sh
#
# Anything that needs a live box (deploy, restart, tunnel) is not covered here.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SFBOX="$TESTS_DIR/../sfbox"

SFBOX_TEST_ROOT="$(mktemp -d)"
export SFBOX_HOME="$SFBOX_TEST_ROOT/gascity"
trap 'rm -rf "$SFBOX_TEST_ROOT"' EXIT

# shellcheck source=../sfbox
. "$SFBOX"

PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; printf '       %s\n' "$2"; }

is() { # actual expected label
  if [ "$1" = "$2" ]; then ok "$3"; else bad "$3" "want [$2], got [$1]"; fi
}

rc_is() { # expected_rc label command...
  local want="$1" label="$2"; shift 2
  # Subshell on purpose: some of these functions exit rather than return, and
  # without it a failing assertion would take the whole run down with it.
  ( "$@" ) >/dev/null 2>&1
  local got=$?
  if [ "$got" = "$want" ]; then ok "$label"; else bad "$label" "want rc $want, got $got"; fi
}

contains() { # haystack needle label
  case "$1" in
    *"$2"*) ok "$3" ;;
    *)      bad "$3" "expected to find [$2]" ;;
  esac
}

fresh_state() {
  rm -rf "$SFBOX_HOME"
  state_init
}

# --------------------------------------------------------------- state -----

echo "state: round-trip and accessors"
fresh_state

state_put alice-prod host 203.0.113.10
state_put alice-prod user ubuntu
state_put alice-prod port 22
state_put alice-prod label prod
state_put alice-test host 203.0.113.11
state_put alice-test port 22
state_set_current alice-prod

is "$(state_get alice-prod host)" "203.0.113.10" "reads a value back"
is "$(state_get alice-test host)" "203.0.113.11" "keeps boxes separate"
is "$(state_get alice-prod nope)" ""             "absent key is empty"
is "$(state_get nobody host)"     ""             "absent box is empty"
is "$(state_boxes | tr '\n' ' ')" "alice-prod alice-test " "lists boxes sorted"
is "$(state_current)" "alice-prod"               "current box round-trips"

state_put alice-prod host 203.0.113.99
is "$(state_get alice-prod host)" "203.0.113.99" "put overwrites in place"
is "$(state_boxes | wc -l | tr -d ' ')" "2"      "overwrite does not duplicate a box"

rc_is 0 "has_box finds a saved box"     state_has_box alice-prod
rc_is 1 "has_box rejects an unknown id" state_has_box nobody

echo "state: the file it writes is valid TOML shape"
contains "$(cat "$SFBOX_HOME/boxes.toml")" '[boxes.alice-prod]' "emits a table header per box"
contains "$(cat "$SFBOX_HOME/boxes.toml")" 'host = "203.0.113.99"' "quotes string values"
contains "$(cat "$SFBOX_HOME/boxes.toml")" 'port = 22'             "leaves integers unquoted"
contains "$(cat "$SFBOX_HOME/boxes.toml")" 'current = "alice-prod"' "keeps current at the top level"

echo "state: re-reading a file we wrote gives the same values"
saved="$(cat "$SFBOX_HOME/boxes.toml")"
printf '%s\n' "$saved" >"$SFBOX_HOME/boxes.toml"
is "$(state_get alice-prod label)" "prod"        "survives a write/read cycle"

echo "state: dropping a box"
state_drop_box alice-test
is "$(state_boxes | tr '\n' ' ')" "alice-prod "  "drops only the named box"
is "$(state_get alice-prod host)" "203.0.113.99" "leaves the other box intact"

echo "state: values with spaces"
fresh_state
state_put b1 city_path "/home/ubuntu/my factory"
is "$(state_get b1 city_path)" "/home/ubuntu/my factory" "keeps spaces in a value"

# ---------------------------------------------------------- github urls ----

echo "github url parsing"
is "$(parse_github_url 'https://github.com/acme/packs/tree/main/factory')" \
   "acme packs main factory" "tree url with ref and subdir"
is "$(parse_github_url 'https://github.com/acme/packs/tree/v1.2.0/a/b')" \
   "acme packs v1.2.0 a/b" "nested subdir"
is "$(parse_github_url 'https://github.com/acme/packs')" \
   "acme packs  " "bare repo url has no ref or subdir"
is "$(parse_github_url 'https://github.com/acme/packs.git')" \
   "acme packs  " "strips a .git suffix"
is "$(parse_github_url 'https://github.com/acme/packs/tree/main')" \
   "acme packs main " "ref with no subdir"

rc_is 1 "rejects a non-github url"     parse_github_url 'https://gitlab.com/acme/packs'
rc_is 1 "rejects a non-url"            parse_github_url 'acme/packs'
rc_is 1 "rejects an unknown url shape" parse_github_url 'https://github.com/acme/packs/blob/main/x'
rc_is 1 "rejects an org with no repo"  parse_github_url 'https://github.com/acme'
rc_is 1 "rejects a trailing-slash org" parse_github_url 'https://github.com/acme/'
rc_is 1 "rejects a bare host"          parse_github_url 'https://github.com/'

# ------------------------------------------------------- flags need values ---

# A flag given without its value used to leave $# at 1, where `shift 2` refuses
# to shift and the parse loop spun forever with no output at all.
echo "flags that are missing their value"
rc_is 1 "save-credential --box with no value" cmd_save_credential --box
rc_is 1 "save-credential --host with no value" cmd_save_credential --box b --host
rc_is 1 "get-box --lines with no value"       cmd_get_box --lines
rc_is 1 "restart-factory --wait with no value" cmd_restart_factory --wait
rc_is 1 "dashboard --port with no value"      cmd_dashboard --port
rc_is 1 "preflight --box with no value"       cmd_preflight --box
rc_is 1 "deploy-factory --version with no value" cmd_deploy_factory url --version

# ------------------------------------------------------ size guardrail -----

echo "prompt-size guardrail"

sizes() { printf '%b' "$1" | evaluate_prompt_sizes >/dev/null 2>&1; printf '%s' $?; }

is "$(sizes 'manager\tOK\t1000\nbuilder\tOK\t2000\n')" "0" \
   "passes when every prompt is small"
is "$(sizes 'manager\tOK\t131071\n')" "0" \
   "passes one byte under the limit"
is "$(sizes 'manager\tOK\t131072\n')" "1" \
   "refuses at exactly the limit, because the NUL terminator counts"
is "$(sizes 'manager\tOK\t190327\n')" "1" \
   "refuses a prompt well over the limit"
is "$(sizes 'manager\tOK\t1000\nbuilder\tOK\t200000\n')" "1" \
   "refuses when any single agent is too large, not just the manager"
is "$(sizes 'manager\tERR\t0\n')" "1" \
   "refuses when an agent cannot be rendered at all"
is "$(sizes 'manager\tOK\tnope\n')" "1" \
   "refuses a size that is not a number instead of reading it as fitting"
is "$(sizes '')" "3" \
   "reports could-not-measure on empty input"

echo "prompt-size guardrail: what it tells the participant"
msg="$(printf 'manager\tOK\t190327\n' | evaluate_prompt_sizes 2>&1)"
contains "$msg" "190327"                     "names the measured size"
contains "$msg" "$SFBOX_MAX_PROMPT_BYTES"    "names the limit"
contains "$msg" "session died during startup" "warns about the misleading error"
contains "$msg" "rolled back"                "says the box was left alone"

# ------------------------------------------------------------ ssh config ---

echo "ssh config generation"
fresh_state
state_put alice-prod host 203.0.113.10
state_put alice-prod user ubuntu
state_put alice-prod port 2222
write_ssh_config
cfg="$(cat "$SFBOX_HOME/ssh_config")"
contains "$cfg" "Host alice-prod"                       "writes a Host stanza"
contains "$cfg" "HostName 203.0.113.10"                 "writes the hostname"
contains "$cfg" "Port 2222"                             "honours a custom port"
contains "$cfg" "IdentitiesOnly yes"                    "pins to our key only"
contains "$cfg" "StrictHostKeyChecking yes"             "keeps strict host checking on"
contains "$cfg" "UserKnownHostsFile $SFBOX_HOME/known_hosts" "uses our own known_hosts"

echo "ssh config: regenerating tracks the boxes we still have"
state_drop_box alice-prod
state_put bob-test host 203.0.113.20
state_put bob-test user ubuntu
state_put bob-test port 22
write_ssh_config
cfg="$(cat "$SFBOX_HOME/ssh_config")"
contains "$cfg" "Host bob-test" "adds the new box"
case "$cfg" in
  *"Host alice-prod"*) bad "drops the removed box" "alice-prod is still in ssh_config" ;;
  *)                   ok  "drops the removed box" ;;
esac

# --------------------------------------------------------------- routing ---

echo "box routing"
fresh_state
state_put alice-prod host 203.0.113.10
state_put alice-test host 203.0.113.11
state_set_current alice-prod

is "$(resolve_box '')"           "alice-prod" "falls back to the current box"
is "$(resolve_box 'alice-test')" "alice-test" "an explicit --box wins"
rc_is 2 "fails on an unknown box" resolve_box nobody

fresh_state
state_put alice-prod host 203.0.113.10
rc_is 2 "fails when nothing is selected" resolve_box ''

# ------------------------------------------------------------------ done ---

echo
printf '%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ] || exit 1
