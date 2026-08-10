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
    fail "gh auth: not authenticated — run 'gh auth login'"
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

if command -v gc >/dev/null 2>&1; then
  ok "gc: $(command -v gc)"
else
  fail "gc: not found on PATH — install Gas City before the first session"
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
  # NOT YET IMPLEMENTED. The cloud branch checks that a participant box
  # credential is configured and that the box actually answers. That depends
  # on the participant box CLI, which ships separately; until it lands there
  # is nothing here to check and a fabricated check would be worse than none.
  echo "  [ -- ] cloud checks are not available yet."
  echo "         The cloud path needs the participant box CLI, which is not part of this repo."
  echo "         Run the local path today. When the box CLI ships, this section will verify"
  echo "         that a box credential is configured and that the box connects."
  echo "         Nothing about the local path is blocked by this."
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
