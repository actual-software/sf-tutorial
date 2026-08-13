#!/usr/bin/env bash
#
# Preflight for the Software Factory Intensive.
#
# Runs every check the first session depends on and prints ONE pass-or-fail
# line at the end. Anyone whose last line reads FAIL gets paired before the
# first block starts.
#
#   ./preflight.sh            # local path (default)
#   ./preflight.sh --cloud    # local path, plus the cloud-box checks
#   ./preflight.sh --install  # run deps.sh first, then check
#
# Safe to run repeatedly. Without --install it changes nothing on your machine.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"

MODE_CLOUD=0
MODE_INSTALL=0
for arg in "$@"; do
  case "$arg" in
    --cloud)   MODE_CLOUD=1 ;;
    --install) MODE_INSTALL=1 ;;
    -h|--help)
      sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

FAILURES=0
WARNINGS=0

ok()   { printf '  [ ok ] %s\n' "$*"; }
fail() { printf '  [FAIL] %s\n' "$*"; FAILURES=$((FAILURES + 1)); }
warn() { printf '  [warn] %s\n' "$*"; WARNINGS=$((WARNINGS + 1)); }
head2() { printf '\n%s\n' "$*"; }

# The pinned versions live in deps.sh so there is exactly one place to change
# them. Read them from there rather than restating them here.
pinned() {
  local var="$1"
  grep -E "^[[:space:]]*${var}=" "${HERE}/deps.sh" 2>/dev/null \
    | head -1 | cut -d= -f2 | tr -d '[:space:]'
}
BD_PINNED="$(pinned BD_VERSION)"
DOLT_PINNED="$(pinned DOLT_VERSION)"
GC_PINNED="$(pinned GC_VERSION)"

# gc is checked against a floor rather than an exact version, matching the gate
# in bootstrap.sh so this script's verdict predicts that one. bootstrap.sh
# carries its own copy of this function, the same way it carries its own
# pinned() — the two scripts are run standalone and share no library.
version_at_least() {
  local have="$1" want="$2" i have_part want_part
  local -a have_parts want_parts
  IFS=. read -r -a have_parts <<< "$have"
  IFS=. read -r -a want_parts <<< "$want"
  for ((i = 0; i < 3; i++)); do
    # Trim any pre-release suffix so 1.4.0-rc1 compares on its numbers, and
    # force base 10 so a zero-padded component is not read as octal.
    have_part="${have_parts[i]:-0}"; have_part="${have_part%%[!0-9]*}"
    want_part="${want_parts[i]:-0}"; want_part="${want_part%%[!0-9]*}"
    if (( 10#${have_part:-0} > 10#${want_part:-0} )); then return 0; fi
    if (( 10#${have_part:-0} < 10#${want_part:-0} )); then return 1; fi
  done
  return 0
}

# --------------------------------------------------------------------------
head2 "Platform"

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"
case "$os" in
  darwin|linux) ok "os: $os" ;;
  *) fail "os: $os is not supported (need darwin or linux)" ;;
esac
case "$arch" in
  x86_64|amd64|arm64|aarch64) ok "arch: $arch" ;;
  *) fail "arch: $arch is not supported (need amd64 or arm64)" ;;
esac

# --------------------------------------------------------------------------
head2 "Required tools"

for tool in git tmux curl jq; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "$tool: $(command -v "$tool")"
  else
    fail "$tool: not found on PATH"
  fi
done

if command -v gh >/dev/null 2>&1; then
  ok "gh: $(gh --version 2>/dev/null | head -1)"
  if gh auth status >/dev/null 2>&1; then
    ok "gh auth: authenticated"
  else
    fail "gh auth: not authenticated — run 'gh auth login', or step 4 of the preflight page for the token route"
  fi
else
  fail "gh: not found on PATH"
fi

# --------------------------------------------------------------------------
head2 "Pinned dependencies"

if [ "$MODE_INSTALL" -eq 1 ]; then
  echo "  running deps.sh ..."
  if bash "${HERE}/deps.sh"; then ok "deps.sh completed"; else fail "deps.sh failed"; fi
fi

case ":${PATH}:" in
  *":${INSTALL_DIR}:"*) ok "PATH includes ${INSTALL_DIR}" ;;
  *) fail "PATH is missing ${INSTALL_DIR} — add: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

check_pin() {
  local name="$1" pinned_version="$2" actual
  if ! command -v "$name" >/dev/null 2>&1; then
    fail "$name: not found — run ./deps.sh (or ./preflight.sh --install)"
    return
  fi
  actual="$("$name" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  if [ -z "$pinned_version" ]; then
    ok "$name: ${actual:-present} (no pin found in deps.sh)"
  elif [ "$actual" = "$pinned_version" ]; then
    ok "$name: $actual (pinned)"
  else
    warn "$name: ${actual:-unknown}, expected the pinned $pinned_version — re-run ./deps.sh if a step misbehaves"
  fi
}
check_pin bd "$BD_PINNED"

if command -v dolt >/dev/null 2>&1; then
  dolt_actual="$(dolt version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  if [ -n "$DOLT_PINNED" ] && [ "$dolt_actual" != "$DOLT_PINNED" ]; then
    warn "dolt: ${dolt_actual:-unknown}, expected the pinned $DOLT_PINNED"
  else
    ok "dolt: ${dolt_actual:-present}"
  fi
else
  fail "dolt: not found — run ./deps.sh (or ./preflight.sh --install)"
fi

# deps.sh builds gc at its pinned commit, and bootstrap.sh refuses to run below
# that version — so a gc under the floor is a FAIL here, not the warning the
# bd and dolt pins get. A newer gc passes: the gate is a floor, not a match.
if command -v gc >/dev/null 2>&1; then
  gc_actual="$(gc version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  if [ -z "$GC_PINNED" ]; then
    ok "gc: ${gc_actual:-present} (no pin found in deps.sh)"
  elif version_at_least "${gc_actual:-0}" "$GC_PINNED"; then
    ok "gc: ${gc_actual:-unknown} (at or above the pinned $GC_PINNED)"
  else
    fail "gc: ${gc_actual:-unknown} is older than the pinned $GC_PINNED — run ./deps.sh (or ./preflight.sh --install)"
  fi
else
  fail "gc: not found — run ./deps.sh (or ./preflight.sh --install)"
fi

# --------------------------------------------------------------------------
head2 "Dolt identity"

# Dolt will not commit without a name and an email, and the first `gc start` on
# a machine that has neither fails outright. bootstrap.sh now fills them in from
# GITHUB_USERNAME; this check only reports, so anyone working through the pages
# by hand sees the gap before it stops them.
if command -v dolt >/dev/null 2>&1; then
  dolt_name="$(dolt config --get user.name 2>/dev/null)"
  dolt_email="$(dolt config --get user.email 2>/dev/null)"
  if [ -n "$dolt_name" ] && [ -n "$dolt_email" ]; then
    ok "dolt identity: $dolt_name <$dolt_email>"
  else
    missing=""
    [ -z "$dolt_name" ] && missing="user.name"
    [ -z "$dolt_email" ] && missing="${missing:+$missing and }user.email"
    warn "dolt identity: $missing unset — gc start needs both; bootstrap.sh sets them from GITHUB_USERNAME"
  fi
else
  warn "dolt identity: not checked, dolt is not installed"
fi

# --------------------------------------------------------------------------
head2 "Local path"

if [ -n "${SOFTWARE_FACTORY_INTENSIVE_PATH:-}" ]; then
  if [ -d "$SOFTWARE_FACTORY_INTENSIVE_PATH" ]; then
    ok "workspace: $SOFTWARE_FACTORY_INTENSIVE_PATH"
  else
    fail "workspace: \$SOFTWARE_FACTORY_INTENSIVE_PATH is set but does not exist"
  fi
else
  warn "workspace: \$SOFTWARE_FACTORY_INTENSIVE_PATH is unset — bootstrap.sh needs it, the progression pages do not"
fi

if [ -w "$HOME" ]; then ok "home directory is writable"; else fail "home directory is not writable"; fi

# --------------------------------------------------------------------------
if [ "$MODE_CLOUD" -eq 1 ]; then
  head2 "Cloud path"

  # sfbox ships in this repo. Prefer a copy on PATH, so a participant who put it
  # somewhere of their own is not second-guessed, and fall back to the one that
  # sits next to this script.
  SFBOX=""
  if command -v sfbox >/dev/null 2>&1; then
    SFBOX="$(command -v sfbox)"
  elif [ -x "${HERE}/../participant-box-cli/sfbox" ]; then
    SFBOX="${HERE}/../participant-box-cli/sfbox"
  fi

  if [ -z "$SFBOX" ]; then
    fail "sfbox: not found — expected it on PATH, or at participant-box-cli/sfbox in this repo"
  else
    ok "sfbox: $SFBOX"

    # `sfbox box current` prints its human-facing lines with a '==> ' prefix and
    # still exits 0 when nothing is selected, so the box id is whatever survives
    # dropping those lines.
    current_box="$("$SFBOX" box current 2>/dev/null | grep -v '^==>' | tr -d '[:space:]')"
    if [ -z "$current_box" ]; then
      fail "box credential: none saved — run 'sfbox save-credential' with the box id, host, key and fingerprint your instructor gave you"
    else
      ok "box credential: $current_box"

      # sfbox preflight is the authority on whether the box answers: it checks
      # ssh, then gc, then the service, and names the layer that broke. Mirror
      # its verdict rather than deriving a second opinion here.
      #
      # It exits 0 when ssh and gc answer but the Gas City service is not
      # active: that layer warns rather than failing. Reading only the exit
      # code would call all three green while the service is down, so carry
      # the warning through instead of dropping the captured output.
      if box_out="$("$SFBOX" preflight 2>&1)"; then
        case "$box_out" in
          *WARNING*)
            warn "box: ssh and gc answered, but sfbox flagged a layer:"
            printf '%s\n' "$box_out" | sed 's/^/         /' ;;
          *)
            ok "box reachable: ssh, gc and the Gas City service all answered" ;;
        esac
      else
        fail "box unreachable — sfbox preflight says which layer broke:"
        printf '%s\n' "$box_out" | sed 's/^/         /'
      fi
    fi
  fi
fi

# --------------------------------------------------------------------------
printf '\n'
if [ "$FAILURES" -eq 0 ]; then
  if [ "$WARNINGS" -gt 0 ]; then
    echo "PREFLIGHT: PASS (${WARNINGS} warning(s) — you are good to start)"
  else
    echo "PREFLIGHT: PASS"
  fi
  exit 0
else
  echo "PREFLIGHT: FAIL (${FAILURES} check(s) failed) — get paired before the first session"
  exit 1
fi
