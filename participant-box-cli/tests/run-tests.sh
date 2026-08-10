#!/usr/bin/env bash
#
# Tests for sfbox. These cover the parts that run on your laptop with no box
# attached: local state, URL parsing, ssh config generation, preflight against
# a stubbed box, and both halves of the prompt-size guardrail (the decision it
# makes, and the ssh command it composes to gather the measurement).
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

# ------------------------------------------------- flags that count things ---

# --wait is the one that matters. The restart poll compares it with -lt, which
# errors on a non-numeric operand and falls out of the loop, so an unchecked
# value made restart-factory report its verdict at once instead of waiting.
echo "flags that have to be numbers"
rc_is 1 "get-box rejects a non-numeric --lines"        cmd_get_box --lines abc
rc_is 1 "restart-factory rejects a non-numeric --wait" cmd_restart_factory --wait soon
rc_is 1 "dashboard rejects a non-numeric --port"       cmd_dashboard --port http

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

echo "prompt-size guardrail: reading the size out of gc prime --json"

# Mirrors the reader inside check_prompt_sizes, which runs on the box inside a
# remote command string and so cannot be called directly from here. The two
# assertions below the fixtures check that the snippet in sfbox still matches.
prime_bytes() { head -c 512 | sed 's/"content":.*//' | grep -o '"bytes":[0-9]*' | head -1 | tr -dc '0-9'; }

is "$(printf '%s' '{"agent":"local-core.manager","bytes":299395,"content":"# Manager\n"}' | prime_bytes)" \
   "299395" "reads the bytes field"
is "$(printf '%s' '{"agent":"bd.dog","bytes":905,"content":""}' | prime_bytes)" \
   "905" "reads a small prompt"
is "$(printf '%s' '{"agent":"m","bytes":299395,"content":"a prompt quoting \"bytes\":1 in its own text"}' | prime_bytes)" \
   "299395" "ignores a bytes-looking string inside the rendered prompt"
is "$(printf '%s' '{"agent":"m","content":"no size here"}' | prime_bytes)" \
   "" "reads empty when the field is gone, which the evaluator then refuses on"
is "$(sizes "manager\tOK\t$(printf '%s' '{"agent":"m","content":"x"}' | prime_bytes)\n")" "1" \
   "a missing bytes field refuses the deploy rather than passing it"

# The quotes are backslashed in sfbox because the reader lives inside a
# double-quoted remote command string, so match it the way it is written.
contains "$(cat "$SFBOX")" '--strict --json'  "sfbox still asks gc prime for JSON"
contains "$(cat "$SFBOX")" 'bytes\":[0-9]*'   "sfbox still reads the bytes field"

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

# ------------------------------------------------------------ instructor ---
#
# The instructor commands reach AWS and Terraform through a handful of one-line
# seam functions, which these tests replace. Nothing below runs an apply, a
# destroy or any other billable call — the seams are the whole point of the
# split, and stubbing them is how the plumbing gets exercised at all.

echo "instructor: boxId validation"
rc_is 0 "accepts a plain boxId"              instructor_validate_box_id alice-prod
rc_is 0 "accepts digits"                     instructor_validate_box_id box2
rc_is 2 "rejects an empty boxId"             instructor_validate_box_id ""
rc_is 2 "rejects a slash"                    instructor_validate_box_id "alice/prod"
rc_is 2 "rejects a space"                    instructor_validate_box_id "alice prod"
rc_is 2 "rejects a dot"                      instructor_validate_box_id "alice.prod"
rc_is 2 "rejects a leading hyphen"           instructor_validate_box_id "-alice"
rc_is 2 "rejects a trailing hyphen"          instructor_validate_box_id "alice-"
rc_is 2 "rejects an over-long boxId"         instructor_validate_box_id "$(printf 'a%.0s' $(seq 61))"

rc_is 2 "provision needs a boxId" cmd_instructor_provision
rc_is 2 "remove needs a boxId"    cmd_instructor_remove
rc_is 2 "rejects an unknown subcommand" cmd_instructor bogus
rc_is 2 "provision rejects an unknown flag" cmd_instructor_provision alice-prod --nope
rc_is 2 "list rejects an unknown flag"      cmd_instructor_list --nope

echo "instructor: flags that are missing their value"
rc_is 1 "provision --tf-root with no value"  cmd_instructor_provision alice-prod --tf-root
rc_is 1 "provision --key-out with no value"  cmd_instructor_provision alice-prod --key-out
rc_is 1 "remove --tf-root with no value"     cmd_instructor_remove alice-prod --tf-root
rc_is 2 "remove rejects --keypair, which the module now owns" \
                                             cmd_instructor_remove alice-prod --keypair mine
rc_is 1 "list --tag-key with no value"       cmd_instructor_list --tag-key

# ---- credentials absent -----------------------------------------------------
#
# A participant has no AWS credentials by design and will run one of these by
# accident. What they get has to say so, not print an SDK stack trace.

echo "instructor: no AWS credentials"
aws_available() { return 1; }
tf_available()  { return 0; }

rc_is 5 "provision stops when the AWS CLI is absent" cmd_instructor_provision alice-prod
rc_is 5 "remove stops when the AWS CLI is absent"    cmd_instructor_remove alice-prod
rc_is 5 "list stops when the AWS CLI is absent"      cmd_instructor_list

msg="$(cmd_instructor_list 2>&1)"
contains "$msg" "you are not missing anything"  "tells a participant they are not blocked"
contains "$msg" "sfbox --help"                  "points them at the commands that are theirs"
case "$msg" in
  *Traceback*|*"Unable to locate credentials"*) bad "no raw SDK error" "leaked an SDK message" ;;
  *)                                            ok  "no raw SDK error" ;;
esac

echo "instructor: AWS CLI present but credentials do not resolve"
aws_available() { return 0; }
aws_cli() { return 255; }
rc_is 5 "stops when sts get-caller-identity fails" cmd_instructor_list
msg="$(cmd_instructor_list 2>&1)"
contains "$msg" "Nothing was changed"    "says it changed nothing"
contains "$msg" "session has probably expired" "gives the instructor the real cause too"

# ---- the describe seam itself -----------------------------------------------
#
# Every section below stubs instructor_describe_rows wholesale, which is the
# right level for testing its callers but never runs the function itself. This
# one exercises the real body against a stubbed aws, because the exit status it
# hands back is the whole reason those callers can fail closed. It runs here, up
# ahead of the stubs, while the real implementation is still in place.

echo "instructor: the describe hands back the AWS exit status"
aws_available() { return 0; }
aws_cli() { printf 'alice-prod\ti-0abc\trunning\tm6i.xlarge\tNone\t10.0.0.5\tt\n'; return 0; }
rc_is 0 "a describe that worked reports success" instructor_describe_rows Workshop sfi
is "$(instructor_describe_rows Workshop sfi | cut -f1)" "alice-prod" "still prints its rows"

aws_cli() { printf 'An error occurred (RequestLimitExceeded) on DescribeInstances\n' >&2; return 254; }
rc_is 254 "a describe that failed reports the failure" instructor_describe_rows Workshop sfi
is "$(instructor_describe_rows Workshop sfi 2>/dev/null)" "" "keeps the AWS error off its stdout"
contains "$(instructor_describe_rows Workshop sfi 2>&1 >/dev/null)" "RequestLimitExceeded" \
                                            "leaves what AWS said on stderr, where the instructor sees it"

# ---- shared stubs for the plumbing tests ------------------------------------

TFROOT="$SFBOX_TEST_ROOT/tfroot"
mkdir -p "$TFROOT"
: >"$TFROOT/main.tf"
TF_LOG="$SFBOX_TEST_ROOT/tf.log"

# remove's three steps span both seams — two Terraform calls and one AWS call —
# and the order between them is the thing worth asserting, so both stubs also
# append to one shared log that a single awk can read the sequence out of.
ORDER_LOG="$SFBOX_TEST_ROOT/order.log"

# What describe-volumes reports after a delete. Deletion is asynchronous, so
# this is what tells remove whether the volume actually went. "gone" is not a
# state AWS returns — it is the stub's way of asking for the other shape, an
# InvalidVolume.NotFound error on a non-zero exit, which is what a volume that
# has finished deleting actually looks like.
VOL_STATE="deleted"

# No sleeping in the suite. The give-up path still needs more than one attempt
# to be worth exercising, so it polls twice and waits none.
export SFBOX_VOLUME_DELETE_ATTEMPTS=2
export SFBOX_VOLUME_DELETE_SLEEP=0

aws_available() { return 0; }
tf_available()  { return 0; }
aws_cli() {
  printf 'aws %s\n' "$*" >>"$ORDER_LOG"
  case "$*" in
    "sts get-caller-identity")  return 0 ;;
    *delete-volume*)            return 0 ;;
    *describe-volumes*)
      # A volume that has finished deleting has no state to report: the lookup
      # fails instead. Emitting that on stderr and exiting non-zero is the only
      # way the stub reaches the branch that reads the error text.
      if [ "$VOL_STATE" = "gone" ]; then
        printf 'An error occurred (InvalidVolume.NotFound) when calling the DescribeVolumes operation: The volume does not exist.\n' >&2
        return 254
      fi
      printf '%s\n' "$VOL_STATE" ;;
    *describe-instances*)       printf 'None\n' ;;
  esac
  return 0
}
keyscan_cli() { printf '203.0.113.9 ssh-ed25519 AAAAC3Nz\n'; }
keygen_cli()  { printf '256 SHA256:TESTFINGERPRINT host (ED25519)\n'; }

# The Terraform side of a healthy participant box: the home volume is in state,
# the root does not re-export home_volume_id (the example root does not), so the
# id has to come back out of `state show`.
stub_tf_ok() {
  tf_cli() {
    printf '%s\n' "$*" >>"$TF_LOG"
    printf 'tf %s\n' "$*" >>"$ORDER_LOG"
    case "$*" in
      *"state list")
        printf 'module.gas_city.aws_instance.main\nmodule.gas_city.aws_ebs_volume.home\n' ;;
      *"output -raw home_volume_id")
        return 1 ;;
      *"state show"*)
        printf 'resource "aws_ebs_volume" "home" {\n    arn = "arn:aws:ec2:us-east-1:1:volume/vol-0home"\n    id  = "vol-0home"\n}\n' ;;
      *"output -raw participant_private_key")
        printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nx\n' ;;
      *"output -raw public_ip")
        printf '203.0.113.9\n' ;;
      *"output -raw instance_id")
        printf 'i-0abc\n' ;;
    esac
    return 0
  }
}

echo "instructor: Terraform root validation"
rc_is 2 "refuses a missing --tf-root"      instructor_require_tf ""
rc_is 2 "refuses a tf-root that is absent" instructor_require_tf "$SFBOX_TEST_ROOT/nope"
rc_is 2 "refuses a directory with no .tf"  instructor_require_tf "$SFBOX_TEST_ROOT"
rc_is 0 "accepts a real Terraform root"    instructor_require_tf "$TFROOT"

# ---- collision detection ----------------------------------------------------
#
# The instructor allocates boxIds by hand, so an id already in use has to be an
# error. Silently applying over it would take somebody else's box.

echo "instructor: boxId collision"
instructor_describe_rows() {
  printf 'alice-prod\ti-0abc\trunning\tm6i.xlarge\t203.0.113.5\t10.0.0.5\t2026-08-10T00:00:00Z\n'
}
rc_is 0 "sees a live box holding the id"  instructor_box_exists alice-prod Workshop sfi
rc_is 6 "provision refuses a taken boxId" cmd_instructor_provision alice-prod --tf-root "$TFROOT" --yes
msg="$(cmd_instructor_provision alice-prod --tf-root "$TFROOT" --yes 2>&1)"
contains "$msg" "already in use"     "names the collision"
contains "$msg" "Nothing was changed" "says it changed nothing"

echo "instructor: a terminated instance does not hold its id"
instructor_describe_rows() {
  printf 'alice-prod\ti-0abc\tterminated\tm6i.xlarge\tNone\t10.0.0.5\t2026-08-10T00:00:00Z\n'
}
rc_is 1 "terminated does not count as live" instructor_box_exists alice-prod Workshop sfi
instructor_describe_rows() {
  printf 'alice-prod\ti-0abc\tshutting-down\tm6i.xlarge\tNone\t10.0.0.5\t2026-08-10T00:00:00Z\n'
}
rc_is 1 "shutting-down does not count as live" instructor_box_exists alice-prod Workshop sfi

# ---- a lookup that errored is not an empty account --------------------------
#
# A denied ec2:DescribeInstances, a throttle and a wrong --region all print
# nothing, exactly like an account with no boxes in it. Reading that silence as
# "the id is free" is how provision would apply over somebody else's box, so the
# guard has to fail closed.

echo "instructor: a lookup that errors is not an empty account"
instructor_describe_rows() {
  printf 'An error occurred (UnauthorizedOperation) on DescribeInstances\n' >&2
  return 254
}
rc_is 2 "box_exists answers 'could not tell' rather than 'free'" \
  instructor_box_exists alice-prod Workshop sfi

: >"$TF_LOG"
tf_cli() { printf '%s\n' "$*" >>"$TF_LOG"; return 0; }
rc_is 8 "provision stops when the collision check could not run" \
  cmd_instructor_provision alice-prod --tf-root "$TFROOT" --yes
msg="$(cmd_instructor_provision alice-prod --tf-root "$TFROOT" --yes 2>&1)"
contains "$msg" "could not complete the EC2 lookup" "names the lookup as what failed"
contains "$msg" "UnauthorizedOperation"             "keeps AWS's own error in front of the instructor"
contains "$msg" "Nothing was changed"               "says it changed nothing"
is "$(cat "$TF_LOG")" "" "an unreadable account reaches Terraform not at all"

echo "instructor: list refuses to show a list it could not read"
rc_is 8 "list stops when the describe fails" \
  cmd_instructor_list --tag-key Workshop --tag-value sfi
msg="$(cmd_instructor_list --tag-key Workshop --tag-value sfi 2>&1)"
contains "$msg" "could not complete the EC2 lookup" "names the lookup as what failed"
case "$msg" in
  *"No workshop boxes"*) bad "does not blame the tag for an error" "printed the empty-list text" ;;
  *)                     ok  "does not blame the tag for an error" ;;
esac

# ---- list formatting --------------------------------------------------------

echo "instructor: list formatting"
rows="$(printf 'alice-prod\ti-0abc\trunning\tm6i.xlarge\t203.0.113.5\t10.0.0.5\tt\nbob-test\ti-0def\trunning\tm6i.xlarge\tNone\t10.0.0.6\tt\n')"
out="$(printf '%s\n' "$rows" | instructor_format_rows)"
contains "$out" "BOX"        "prints a header"
contains "$out" "alice-prod" "lists the first box"
contains "$out" "bob-test"   "lists the second box"
contains "$out" "i-0abc"     "shows the instance id"
case "$out" in
  *None*) bad "renders a missing public IP as a dash" "left the literal None in the table" ;;
  *)      ok  "renders a missing public IP as a dash" ;;
esac
is "$(printf '' | instructor_format_rows)" "__SFBOX_NO_ROWS__" "signals an empty result"

echo "instructor: list with nothing tagged"
instructor_describe_rows() { : ; }
msg="$(cmd_instructor_list --tag-key Workshop --tag-value sfi 2>&1)"
contains "$msg" "No workshop boxes"  "says the list is empty"
contains "$msg" "default_tags"       "explains the likely tag reason"
rc_is 0 "an empty list is not an error" cmd_instructor_list

# ---- remove is a destroy ----------------------------------------------------
#
# The whole point of the Terraform route: it takes the dependent graph with it.
# A terminate-instances would leave the volume and its address billing.

echo "instructor: remove runs a Terraform destroy"
: >"$TF_LOG"; : >"$ORDER_LOG"; VOL_STATE="deleted"
stub_tf_ok
rc_is 0 "removes a box cleanly" \
  cmd_instructor_remove alice-prod --tf-root "$TFROOT" --yes
log="$(cat "$TF_LOG")"
contains "$log" "destroy"                   "runs terraform destroy"
contains "$log" "factory_name=alice-prod"   "passes the boxId as factory_name"
contains "$log" "participant_access=true"   "destroys in the same access mode it was applied in"
contains "$log" "workspace"                 "selects the per-box workspace"
contains "$log" "-chdir=$TFROOT"            "runs against the given root"
case "$log" in
  *"apply "*) bad "never applies during a remove" "remove issued an apply" ;;
  *)          ok  "never applies during a remove" ;;
esac
# The module rejects a caller-supplied keypair_name in participant mode, because
# it mints the pair itself. Passing one is now a plan-time error rather than the
# required variable it used to be.
case "$log" in
  *keypair_name*) bad "leaves keypair_name to the module" "passed keypair_name anyway" ;;
  *)              ok  "leaves keypair_name to the module" ;;
esac

# ---- the home volume ---------------------------------------------------------
#
# prevent_destroy = true takes a literal, so no variable turns it off for a box
# meant to be disposable, and a plain destroy of a participant box refuses. The
# volume has to leave state first and be deleted by hand afterwards. Getting the
# order wrong is not a cosmetic failure: a delete that runs before the destroy
# hits a volume still attached, and a destroy with no delete after it leaves a
# 128 GB volume billing that Terraform can no longer see.

echo "instructor: remove takes the home volume out of state, then deletes it"
: >"$TF_LOG"; : >"$ORDER_LOG"; VOL_STATE="deleted"
stub_tf_ok
out="$(cmd_instructor_remove alice-prod --tf-root "$TFROOT" --yes 2>&1)"
log="$(cat "$TF_LOG")"
contains "$log" "state rm module.gas_city.aws_ebs_volume.home" \
                                            "drops the home volume from state"
contains "$(cat "$ORDER_LOG")" "delete-volume --volume-id vol-0home" \
                                            "deletes the volume it read out of state"
contains "$(cat "$ORDER_LOG")" "describe-volumes --volume-ids vol-0home" \
                                            "confirms the delete rather than trusting it"
contains "$out" "vol-0home"                 "names the volume it acted on"

seq="$(awk '
  /^tf .*state rm/         { print "state-rm" }
  /^tf .*destroy /         { print "destroy" }
  /^aws ec2 delete-volume/ { print "delete-volume" }
' "$ORDER_LOG" | paste -sd, -)"
is "$seq" "state-rm,destroy,delete-volume" \
                                            "runs the three steps in the order that stops the billing"

echo "instructor: remove finds the volume even when the module block is renamed"
: >"$TF_LOG"; : >"$ORDER_LOG"; VOL_STATE="deleted"
stub_tf_ok
tf_cli() {
  printf '%s\n' "$*" >>"$TF_LOG"
  printf 'tf %s\n' "$*" >>"$ORDER_LOG"
  case "$*" in
    *"state list")   printf 'module.workshop_box.aws_ebs_volume.home\n' ;;
    *"state show"*)  printf '    id  = "vol-0renamed"\n' ;;
  esac
  return 0
}
cmd_instructor_remove alice-prod --tf-root "$TFROOT" --yes >/dev/null 2>&1
contains "$(cat "$TF_LOG")" "state rm module.workshop_box.aws_ebs_volume.home" \
                                            "searches state instead of assuming module.gas_city"

echo "instructor: remove prefers the root's home_volume_id output when it has one"
: >"$TF_LOG"; : >"$ORDER_LOG"; VOL_STATE="deleted"
tf_cli() {
  printf '%s\n' "$*" >>"$TF_LOG"
  printf 'tf %s\n' "$*" >>"$ORDER_LOG"
  case "$*" in
    *"state list")                  printf 'module.gas_city.aws_ebs_volume.home\n' ;;
    *"output -raw home_volume_id")  printf 'vol-0fromoutput\n' ;;
    *"state show"*)                 printf '    id  = "vol-0fromstate"\n' ;;
  esac
  return 0
}
cmd_instructor_remove alice-prod --tf-root "$TFROOT" --yes >/dev/null 2>&1
contains "$(cat "$ORDER_LOG")" "delete-volume --volume-id vol-0fromoutput" \
                                            "uses the output the module exposes for exactly this"

echo "instructor: remove stops rather than stranding a volume it cannot name"
: >"$TF_LOG"; : >"$ORDER_LOG"
tf_cli() {
  printf '%s\n' "$*" >>"$TF_LOG"
  case "$*" in
    *"state list")  printf 'module.gas_city.aws_ebs_volume.home\n' ;;
    *"state show"*) : ;;
  esac
  return 0
}
rc_is 9 "refuses when the volume id is unreadable" \
  cmd_instructor_remove alice-prod --tf-root "$TFROOT" --yes
msg="$(cmd_instructor_remove alice-prod --tf-root "$TFROOT" --yes 2>&1)"
contains "$msg" "volume id could not be read" "names what it could not read"
contains "$msg" "nothing was destroyed"      "stops before it can strand anything"
case "$(cat "$TF_LOG")" in
  *"state rm"*) bad "does not drop state it cannot name" "ran state rm anyway" ;;
  *)            ok  "does not drop state it cannot name" ;;
esac

echo "instructor: a volume that outlives the destroy is reported, not swallowed"
: >"$TF_LOG"; : >"$ORDER_LOG"; VOL_STATE="available"
stub_tf_ok
rc_is 9 "reports a volume that is still there" \
  cmd_instructor_remove alice-prod --tf-root "$TFROOT" --yes
msg="$(cmd_instructor_remove alice-prod --tf-root "$TFROOT" --yes 2>&1)"
contains "$msg" "home volume vol-0home is still there" "says which volume survived"
contains "$msg" "aws ec2 delete-volume --volume-id vol-0home" \
                                            "hands over a command that finishes the job"
VOL_STATE="deleted"

# The usual real-world ending, and the one the README tells the instructor to
# look for. A volume that has finished deleting does not report a state — the
# describe fails with InvalidVolume.NotFound. Reading that as anything but
# success would make every healthy remove exit 9 and send the instructor after
# a volume that is already gone, and the state-string cases above would all
# still pass while it did.
echo "instructor: a volume that has finished deleting counts as gone, not as a failure"
: >"$TF_LOG"; : >"$ORDER_LOG"; VOL_STATE="gone"
stub_tf_ok
rc_is 0 "reads InvalidVolume.NotFound as deleted" \
  cmd_instructor_remove alice-prod --tf-root "$TFROOT" --yes
msg="$(cmd_instructor_remove alice-prod --tf-root "$TFROOT" --yes 2>&1)"
contains "$msg" "Home volume vol-0home deleted" "reports the delete it confirmed"
VOL_STATE="deleted"

echo "instructor: a destroy that fails still names the volume it dropped from state"
: >"$TF_LOG"; : >"$ORDER_LOG"
tf_cli() {
  printf '%s\n' "$*" >>"$TF_LOG"
  case "$*" in
    *"state list")   printf 'module.gas_city.aws_ebs_volume.home\n' ;;
    *"state show"*)  printf '    id  = "vol-0home"\n' ;;
    *destroy*)       return 1 ;;
  esac
  return 0
}
rc_is 1 "surfaces a failed terraform destroy" \
  cmd_instructor_remove alice-prod --tf-root "$TFROOT" --yes
msg="$(cmd_instructor_remove alice-prod --tf-root "$TFROOT" --yes 2>&1)"
contains "$msg" "vol-0home is already out of state" \
                                            "warns that a retry will not collect the volume"

echo "instructor: remove carries on when the state holds no home volume"
: >"$TF_LOG"; : >"$ORDER_LOG"
tf_cli() {
  printf '%s\n' "$*" >>"$TF_LOG"
  printf 'tf %s\n' "$*" >>"$ORDER_LOG"
  case "$*" in
    *"state list") printf 'module.gas_city.aws_instance.main\n' ;;
  esac
  return 0
}
rc_is 0 "destroys a workspace with no home volume in it" \
  cmd_instructor_remove alice-prod --tf-root "$TFROOT" --yes
contains "$(cat "$TF_LOG")" "destroy"        "still runs the destroy"
case "$(cat "$ORDER_LOG")" in
  *delete-volume*) bad "deletes no volume it never found" "issued a delete-volume" ;;
  *)               ok  "deletes no volume it never found" ;;
esac
msg="$(cmd_instructor_remove alice-prod --tf-root "$TFROOT" --yes 2>&1)"
contains "$msg" "no aws_ebs_volume.home"     "says the volume was not there to drop"

echo "instructor: remove asks for the boxId before destroying"
: >"$TF_LOG"; : >"$ORDER_LOG"
stub_tf_ok
printf 'not-the-box\n' | cmd_instructor_remove alice-prod --tf-root "$TFROOT" >/dev/null 2>&1
is "$(grep -c destroy "$TF_LOG" | tr -d ' ')" "0" "a mistyped confirmation destroys nothing"
case "$(cat "$ORDER_LOG")" in
  *delete-volume*) bad "a mistyped confirmation deletes no volume" "issued a delete-volume" ;;
  *)               ok  "a mistyped confirmation deletes no volume" ;;
esac

# ---- provision plumbing -----------------------------------------------------

echo "instructor: provision plumbing"
instructor_describe_rows() { : ; }
: >"$TF_LOG"; : >"$ORDER_LOG"
rm -f "$TFROOT/alice-prod-keypair.pem"
stub_tf_ok
out="$(cmd_instructor_provision alice-prod --tf-root "$TFROOT" --yes \
        --factory-packs-ref deps-gc-v1.3.5-bd-1.1.0-pins 2>&1)"
prc=$?
log="$(cat "$TF_LOG")"
is "$prc" "0" "provision succeeds when the box comes up"
contains "$log" "apply"                     "runs terraform apply"
contains "$log" "factory_name=alice-prod"   "passes the boxId as factory_name"
contains "$log" "participant_access=true"   "applies in the mode a participant can reach"
contains "$log" "factory_packs_ref=deps-gc-v1.3.5-bd-1.1.0-pins" \
                                            "passes the packs-ref override through"
contains "$out" "203.0.113.9"               "emits the host"
contains "$out" "SHA256:TESTFINGERPRINT"    "emits the host-key fingerprint"
contains "$out" "alice-prod-keypair.pem"    "emits the private key path"
contains "$out" "sfbox save-credential"     "hands over a line the participant can paste"
rc_is 0 "wrote the private key at 0600" test -f "$TFROOT/alice-prod-keypair.pem"
is "$(ls -l "$TFROOT/alice-prod-keypair.pem" | cut -c1-10)" "-rw-------" "key file is 0600"

# The whole point of the folded-in fix. A pair minted with aws ec2
# create-key-pair sits outside Terraform, so remove's destroy never takes it,
# and re-provisioning a reused boxId lands on a key whose private half is gone.
echo "instructor: the key pair is Terraform's, not provision's"
contains "$(cat "$TFROOT/alice-prod-keypair.pem")" "BEGIN OPENSSH PRIVATE KEY" \
                                            "writes the key the module handed back"
contains "$log" "output -raw participant_private_key" \
                                            "reads the private half out of the apply"
case "$(cat "$ORDER_LOG")" in
  *create-key-pair*) bad "mints no key pair of its own" "called aws ec2 create-key-pair" ;;
  *)                 ok  "mints no key pair of its own" ;;
esac
case "$log" in
  *keypair_name*) bad "passes no keypair_name the module would reject" "passed one" ;;
  *)              ok  "passes no keypair_name the module would reject" ;;
esac
rc_is 2 "rejects --keypair, which the module now owns" \
  cmd_instructor_provision alice-prod --tf-root "$TFROOT" --keypair mine --yes

echo "instructor: provision refuses to hand back a box with no participant key"
: >"$TF_LOG"; : >"$ORDER_LOG"
rm -f "$TFROOT/alice-prod-keypair.pem"
tf_cli() {
  printf '%s\n' "$*" >>"$TF_LOG"
  case "$*" in
    *"output -raw public_ip")   printf '203.0.113.9\n' ;;
    *"output -raw instance_id") printf 'i-0abc\n' ;;
  esac
  return 0
}
rc_is 7 "stops when participant_private_key is null" \
  cmd_instructor_provision alice-prod --tf-root "$TFROOT" --yes
msg="$(cmd_instructor_provision alice-prod --tf-root "$TFROOT" --yes 2>&1)"
contains "$msg" "no private key for the participant" "names what is missing"
contains "$msg" "participant access mode"            "names the cause"
rc_is 1 "writes no key file it could not fill" test -f "$TFROOT/alice-prod-keypair.pem"

echo "instructor: the packs-ref flag is optional"
: >"$TF_LOG"; : >"$ORDER_LOG"
rm -f "$TFROOT/alice-prod-keypair.pem"
stub_tf_ok
cmd_instructor_provision alice-prod --tf-root "$TFROOT" --yes >/dev/null 2>&1
case "$(cat "$TF_LOG")" in
  *factory_packs_ref*) bad "omits factory_packs_ref when not asked for" "passed it anyway" ;;
  *)                   ok  "omits factory_packs_ref when not asked for" ;;
esac

# ---- a root that is not in participant mode ---------------------------------
#
# public_ip is null unless the root ran with participant_access, which is what
# puts the box in the public subnet. Without it the only way in is SSM, and
# participants hold no AWS credentials. Provision has to say so rather than hand
# back a private IP dressed up as a host.

echo "instructor: provision refuses to hand back an unreachable box"
: >"$TF_LOG"; : >"$ORDER_LOG"
rm -f "$TFROOT/alice-prod-keypair.pem"
tf_cli() {
  printf '%s\n' "$*" >>"$TF_LOG"
  case "$*" in
    *"output -raw participant_private_key") printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nx\n' ;;
    *"output -raw instance_id")             printf 'i-0abc\n' ;;
  esac
  return 0
}
rc_is 7 "refuses when the box has no reachable address" \
  cmd_instructor_provision alice-prod --tf-root "$TFROOT" --yes
msg="$(cmd_instructor_provision alice-prod --tf-root "$TFROOT" --yes 2>&1)"
contains "$msg" "no address a participant can reach" "names the real problem"
contains "$msg" "participant access mode"            "names the root setting behind it"
contains "$msg" "Nothing was destroyed"              "leaves the box alone"

echo "instructor: a failed apply is not reported as a provision"
: >"$TF_LOG"; : >"$ORDER_LOG"
rm -f "$TFROOT/alice-prod-keypair.pem"
tf_cli() {
  printf '%s\n' "$*" >>"$TF_LOG"
  case "$*" in
    *apply*) return 1 ;;
  esac
  return 0
}
rc_is 1 "surfaces a failed terraform apply" \
  cmd_instructor_provision alice-prod --tf-root "$TFROOT" --yes

# ---- preflight --------------------------------------------------------------
#
# Preflight is the one command whose whole job is telling "my factory is broken"
# apart from "my ssh is broken", so a false alarm from it is worse than no
# check at all. Both faults these cover fired on the first real workshop box:
# gc probed over a non-login shell reported NOT FOUND, and a service that had
# simply not been started yet reported as a fault.
#
# The stub answers as a provisioned box does: gc resolves only through a login
# shell, and the service state plus the first-run marker are whatever the case
# under test sets.

echo "preflight: the box stub"
fresh_state
state_put sfi-test-1 host 203.0.113.20
state_put sfi-test-1 user ubuntu
state_put sfi-test-1 port 22
state_set_current sfi-test-1

SSH_LOG="$SFBOX_TEST_ROOT/ssh.log"
BOX_ACTIVE="active"
BOX_FIRST_RUN=0          # 0 logged in, 1 not yet, 2 cannot tell

box_ssh() { # box command...
  local box="$1"; shift
  local cmd="$*"
  printf '%s\n' "$cmd" >>"$SSH_LOG"
  case "$cmd" in
    'echo ok')            printf 'ok\n' ;;
    # A non-login shell on a real box: ~/.local/bin is not on PATH.
    'command -v gc')      return 127 ;;
    *'bash -lc'*gc*)      printf '/home/ubuntu/.local/bin/gc\n' ;;
    *systemctl*is-active*) printf '%s\n' "$BOX_ACTIVE" ;;
    *gas-city.env*)       return "$BOX_FIRST_RUN" ;;
    *) : ;;
  esac
  return 0
}

echo "preflight: gc is probed through a login shell"
: >"$SSH_LOG"; BOX_ACTIVE="active"; BOX_FIRST_RUN=0
rc_is 0 "a healthy box passes" cmd_preflight --box sfi-test-1
out="$(cmd_preflight --box sfi-test-1 2>&1)"
contains "$out" "gc             installed"  "reports gc as present"
contains "$(cat "$SSH_LOG")" "bash -lc"     "asks a login shell, not the bare one"
contains "$out" "gas-city.service  active"  "reports the running service"

echo "preflight: a box that has never been logged in is not a fault"
: >"$SSH_LOG"; BOX_ACTIVE="inactive"; BOX_FIRST_RUN=1
rc_is 0 "a not-yet-logged-in box still passes" cmd_preflight --box sfi-test-1
out="$(cmd_preflight --box sfi-test-1 2>&1)"
contains "$out" "waiting on first-run login" "names the state instead of crying wolf"
contains "$out" "sudo gas-city-login"        "names the command that finishes setup"
contains "$out" "gc             installed"   "still reports gc as present"
case "$out" in
  *WARNING*) bad "raises no warning on an expected state" "warned anyway" ;;
  *)         ok  "raises no warning on an expected state" ;;
esac

echo "preflight: a service that died after login still warns"
: >"$SSH_LOG"; BOX_ACTIVE="failed"; BOX_FIRST_RUN=0
out="$(cmd_preflight --box sfi-test-1 2>&1)"
contains "$out" "WARNING"                    "warns about the genuine failure"
contains "$out" "gas-city.service  failed"   "reports the state systemd gave"
case "$out" in
  *gas-city-login*) bad "sends no one after a login they already did" "named the login" ;;
  *)                ok  "sends no one after a login they already did" ;;
esac

echo "preflight: an unreadable /etc/gas-city.env falls back to warning"
: >"$SSH_LOG"; BOX_ACTIVE="inactive"; BOX_FIRST_RUN=2
out="$(cmd_preflight --box sfi-test-1 2>&1)"
contains "$out" "WARNING"                    "warns when it cannot tell the two apart"

echo "preflight: ssh is reported before anything that depends on it"
: >"$SSH_LOG"
box_ssh() { return 255; }
rc_is 1 "an unreachable box fails" cmd_preflight --box sfi-test-1
out="$(cmd_preflight --box sfi-test-1 2>&1)"
contains "$out" "ssh            FAILED"      "blames ssh, not the factory"
case "$out" in
  *"gc  "*) bad "probes nothing else once ssh is down" "probed gc anyway" ;;
  *)        ok  "probes nothing else once ssh is down" ;;
esac

# The wrapper quotes a whole command into a single `bash -lc` argument, and it
# is quoted twice on the way: once into the -lc argument, once again for the
# remote shell. Get that wrong and every gc command over ssh breaks in a way the
# case-matching stubs above would happily wave through. ssh joins its argv with
# spaces and hands the result to a shell, so parsing the captured string the way
# that shell would is exactly what the box sees.
parse_remote() { # captured-string index
  local captured="$1" idx="$2"
  eval "set -- $captured"
  eval "printf '%s' \"\${$idx}\""
}

echo "preflight: the login-shell wrapper survives the trip through ssh"
CAPTURED=""
box_ssh() { shift; CAPTURED="$*"; }
box_ssh_login sfi-test-1 'cd /home/ubuntu/my city && gc session list'
is "$(parse_remote "$CAPTURED" 1)" "bash" "invokes bash on the box"
is "$(parse_remote "$CAPTURED" 2)" "-lc"  "as a login shell"
is "$(parse_remote "$CAPTURED" 3)" 'cd /home/ubuntu/my city && gc session list' \
                                          "hands the command over intact, spaces and all"

# box_gc composes on top of the wrapper, so the same trip has to survive an
# argument that needs quoting of its own.
box_gc sfi-test-1 '/home/ubuntu/city' import add 'https://example.invalid/p.git' --version 'v1 2'
is "$(parse_remote "$CAPTURED" 3)" \
   "cd /home/ubuntu/city && gc import add https://example.invalid/p.git --version v1\\ 2" \
                                          "box_gc reaches gc through the login shell"

# The size guardrail is the last gc caller over ssh, and the one whose failure
# is silent: it drops stderr, so a gc that does not resolve is indistinguishable
# from a box with no agents, and the deploy refuses on a healthy factory rather
# than reporting why. Its remote script is many lines rather than one, so it
# also checks the wrapper on a command that has to survive embedded newlines.
#
# It reads the command back from a file rather than a variable: this caller
# wraps the ssh in a command substitution, so a stub that recorded into a
# variable would set it in that subshell and leave the parent holding whatever
# the previous case left behind — passing the shape assertions while proving
# nothing about this one.
CAPTURED_FILE="$SFBOX_TEST_ROOT/captured-remote"
box_ssh() { shift; printf '%s' "$*" >"$CAPTURED_FILE"; }
: >"$CAPTURED_FILE"
check_prompt_sizes sfi-test-1 '/home/ubuntu/city' >/dev/null 2>&1
CAPTURED="$(cat "$CAPTURED_FILE")"

# The wrapper check comes first and gates the parse. parse_remote evals what it
# is handed, which is safe once the script is quoted into a single argument and
# emphatically is not before: unwrapped, this particular script evals down to a
# `while read` with nothing on stdin, so a regression here would hang the suite
# rather than fail it.
case "$CAPTURED" in
  "bash -lc "*)
    ok "the size guardrail reaches gc through a login shell"
    contains "$(parse_remote "$CAPTURED" 3)" "gc agent list" \
                                          "carries its gc calls into the login shell"
    contains "$(parse_remote "$CAPTURED" 3)" "gc prime" \
                                          "carries both gc calls, not just the first"
    ;;
  *)
    bad "the size guardrail reaches gc through a login shell" \
        "sent the script raw: [$(printf '%s' "$CAPTURED" | head -1)]"
    ;;
esac

# ------------------------------------------------------------------ done ---

echo
printf '%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ] || exit 1
