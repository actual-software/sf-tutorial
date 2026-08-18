#!/usr/bin/env bash

TUTORIAL_STEP="$1"

if [ -z "$TUTORIAL_STEP" ]; then
  echo "==> Usage: ./bootstrap.sh <TUTORIAL_STEP>"
  echo "==> Please pass the tutorial step as the first argument."
  exit 1
fi

# Portable in-place sed: BSD sed (macOS) requires an empty arg after -i, GNU sed (Linux) does not.
if [[ "$(uname -s)" == "Darwin" ]]; then
  SED_I=(-i '')
else
  SED_I=(-i)
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

if [ -z "$BD_PINNED" ] || [ -z "$DOLT_PINNED" ] || [ -z "$GC_PINNED" ]; then
  echo "==> Could not read the pinned versions from ${HERE}/deps.sh"
  echo "==> Expected BD_VERSION, DOLT_VERSION and GC_VERSION to be declared there."
  exit 1
fi

read -p "Are you comfortable with resetting all of \$SOFTWARE_FACTORY_INTENSIVE_PATH? (Y/n) " confirm
if [ "$confirm" != "Y" ]; then
  echo "==> Exiting script."
  exit 1
fi

echo "==> Continuing script."

if ! command -v bd &> /dev/null; then
  echo "==> bd could not be found"
  echo "==> Please install bd."
  exit 1
fi

bd_version=$(bd version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [[ "$bd_version" != "$BD_PINNED" ]]; then
  echo "==> bd is not on the correct version (found: ${bd_version:-unknown})"
  echo "==> Please install bd ${BD_PINNED}."
  exit 1
fi

if ! command -v gc &> /dev/null; then
  echo "==> gc could not be found"
  echo "==> Please run ./deps.sh, which builds the pinned gc."
  exit 1
fi

# gc is checked as a MINIMUM, not an exact match. deps.sh now builds gc at its
# pinned commit, so anyone who ran it arrives exactly on the pin — but a
# participant who installed a newer gc themselves should still get through. An
# exact-match gate rejects every one of them the moment gc moves, which is what
# it did. The floor tracks the pin in deps.sh, so raising it stays one edit.
GC_MIN_VERSION="$GC_PINNED"

# Compare dotted versions without `sort -V`, which macOS's BSD sort does not
# have. Succeeds when $1 is at least $2, padding missing components with 0 so
# "1.2" and "1.2.0" compare equal.
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

gc_version=$(gc version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if ! version_at_least "$gc_version" "$GC_MIN_VERSION"; then
  echo "==> gc is older than this tutorial supports (found: ${gc_version:-unknown})"
  echo "==> Please run ./deps.sh, which builds gc ${GC_MIN_VERSION}."
  exit 1
fi

if ! command -v dolt &> /dev/null; then
  echo "==> dolt could not be found"
  echo "==> Please install dolt."
  exit 1
fi

dolt_version=$(dolt version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [[ "$dolt_version" != "$DOLT_PINNED" ]]; then
  echo "==> dolt is not on the correct version (found: ${dolt_version:-unknown})"
  echo "==> Please install dolt ${DOLT_PINNED}."
  exit 1
fi

if [ ! -f .env ]; then
  echo "==> .env file not found"
  echo "==> Please create a .env file in this folder with the correct values."
  exit 1
fi

# Initial Setup:

source .env

# Where the pack and doc artifacts are copied from. This is the checkout the
# script was run out of, which is deliberately not assumed to sit under
# $SOFTWARE_FACTORY_INTENSIVE_PATH: the mismatch check below lets a participant
# continue with the two split apart, and the copies still have to come from the
# tree they actually cloned. Script-local on purpose, so the only path variable
# a participant ever exports is $SOFTWARE_FACTORY_INTENSIVE_PATH.
ARTIFACTS_SRC="$(cd .. && pwd -P)/artifacts"

TUTORIAL_STEP=$(echo "$TUTORIAL_STEP" | sed 's/\.md$//')

if ! [[ "$TUTORIAL_STEP" =~ ^(00\.1-setup-foundation|00\.2-setup-foundation|00\.3-setup-foundation|01-basic-flow|02-first-review-loop|03-branch-protection|04-adr-reviewer|05\.1-bead-gate-checks|05\.2-bead-gate-checks)$ ]]; then
  echo "==> TUTORIAL_STEP argument is not valid"
  echo "==> Please pass one of the following values as the first argument:

00.1-setup-foundation
00.2-setup-foundation
00.3-setup-foundation
01-basic-flow
02-first-review-loop
03-branch-protection
04-adr-reviewer
05.1-bead-gate-checks
05.2-bead-gate-checks"
  exit 1
fi

if [ -z "$SOFTWARE_FACTORY_INTENSIVE_PATH" ]; then
  echo "==> SOFTWARE_FACTORY_INTENSIVE_PATH environment variable not found"
  echo "==> Please set the SOFTWARE_FACTORY_INTENSIVE_PATH environment variable in the .env file."
  exit 1
fi

# Sanity check: warn if .env's SOFTWARE_FACTORY_INTENSIVE_PATH doesn't match
# the parent directory of sf-tutorial. A mismatch typically means the user
# has sf-tutorial cloned somewhere other than what .env says, which would
# create two parallel software-factory-intensive trees (one with sf-tutorial,
# another with factory1/ascii-art). Most of the time this is misconfiguration,
# not intent — so stop and let the user confirm or abort.
DERIVED_SFI_PATH="$(cd ../.. && pwd -P)"
if [ -d "$SOFTWARE_FACTORY_INTENSIVE_PATH" ]; then
  NORMALIZED_ENV_SFI="$(cd "$SOFTWARE_FACTORY_INTENSIVE_PATH" && pwd -P)"
else
  NORMALIZED_ENV_SFI="${SOFTWARE_FACTORY_INTENSIVE_PATH%/}"
fi
if [ "$NORMALIZED_ENV_SFI" != "$DERIVED_SFI_PATH" ]; then
  echo ""
  echo "==> WARNING: SOFTWARE_FACTORY_INTENSIVE_PATH does not match the parent of sf-tutorial."
  echo ""
  echo "    .env SOFTWARE_FACTORY_INTENSIVE_PATH : $SOFTWARE_FACTORY_INTENSIVE_PATH"
  echo "    sf-tutorial parent directory         : $DERIVED_SFI_PATH"
  echo ""
  echo "    Continuing will run the bootstrap against the .env path, leaving"
  echo "    sf-tutorial separate from factory1/ascii-art. If that's not what"
  echo "    you want, abort and either move sf-tutorial or fix .env."
  echo ""
  read -p "Continue anyway? (Y/n) " sfi_path_confirm
  if [ "$sfi_path_confirm" != "Y" ]; then
    echo "==> Exiting script."
    exit 1
  fi
fi

if [ -z "$MODEL_PROVIDER" ]; then
  echo "==> MODEL_PROVIDER environment variable not found"
  echo "==> Please set the MODEL_PROVIDER environment variable in the .env file."
  exit 1
fi

if ! [[ "$MODEL_PROVIDER" =~ ^(claude|codex|gemini)$ ]]; then
  echo "==> MODEL_PROVIDER environment variable is not valid"
  echo "==> Please set the MODEL_PROVIDER environment variable to a valid value (claude, codex, gemini)."
  exit 1
fi

if [ -z "$GITHUB_USERNAME" ]; then
  echo "==> GITHUB_USERNAME environment variable not found"
  echo "==> Please set the GITHUB_USERNAME environment variable in the .env file."
  exit 1
fi

if [ -z "$ASCII_ART_REPO_EXISTS" ]; then
  echo "==> ASCII_ART_REPO_EXISTS environment variable not found"
  echo "==> Please set the ASCII_ART_REPO_EXISTS environment variable in the .env file."
  exit 1
fi

if ! [[ "$ASCII_ART_REPO_EXISTS" =~ ^(true|false)$ ]]; then
  echo "==> ASCII_ART_REPO_EXISTS environment variable is not valid"
  echo "==> Please set the ASCII_ART_REPO_EXISTS environment variable to a valid value (true, false)."
  exit 1
fi

if [ -z "$ALLOW_ASCII_ART_PUSH_FORCE" ]; then
  echo "==> ALLOW_ASCII_ART_PUSH_FORCE environment variable not found"
  echo "==> Please set the ALLOW_ASCII_ART_PUSH_FORCE environment variable in the .env file."
  exit 1
fi

if ! [[ "$ALLOW_ASCII_ART_PUSH_FORCE" =~ ^(true|false)$ ]]; then
  echo "==> ALLOW_ASCII_ART_PUSH_FORCE environment variable is not valid"
  echo "==> Please set the ALLOW_ASCII_ART_PUSH_FORCE environment variable to a valid value (true, false)."
  exit 1
fi

if [ -z "$FACTORY_VERSION_CONTROL" ]; then
  echo "==> FACTORY_VERSION_CONTROL environment variable not found"
  echo "==> Please set the FACTORY_VERSION_CONTROL environment variable in the .env file."
  exit 1
fi

if ! [[ "$FACTORY_VERSION_CONTROL" =~ ^(true|false)$ ]]; then
  echo "==> FACTORY_VERSION_CONTROL environment variable is not valid"
  echo "==> Please set the FACTORY_VERSION_CONTROL environment variable to a valid value (true, false)."
  exit 1
fi

# Dolt refuses to commit without an identity, so on a fresh machine the first
# `gc start` fails outright with "set the Dolt identity, then run 'gc start'".
# Nothing else in the tutorial sets it, so derive it from GITHUB_USERNAME
# (validated just above) rather than asking for two more .env values. Each
# field is filled only when empty, so an existing Dolt identity is left alone.
if [ -z "$(dolt config --get user.name 2>/dev/null)" ]; then
  echo "==> Setting the Dolt user.name to $GITHUB_USERNAME"
  dolt config --global --add user.name "$GITHUB_USERNAME"
fi
if [ -z "$(dolt config --get user.email 2>/dev/null)" ]; then
  echo "==> Setting the Dolt user.email to $GITHUB_USERNAME@users.noreply.github.com"
  dolt config --global --add user.email "$GITHUB_USERNAME@users.noreply.github.com"
fi

# Hint printed on script exit. Defined after env validation so it doesn't
# fire for runs that bailed before beads/dolt setup was relevant.
print_beads_dolt_hint() {
  echo ""
  echo "==> Heads-up: beads/Dolt troubleshooting"
  echo "    gc's supervisor manages Dolt per rig in SERVER mode. If you hit"
  echo "    'Dolt server unreachable' or 'failed to open database':"
  echo ""
  echo "      1. Try 'gc stop && gc start' first — the supervisor starts and"
  echo "         stops Dolt for you. This is the intended knob."
  echo "      2. If that doesn't fix it, troubleshoot with Claude Code (or"
  echo "         another agent)."
  echo "      3. CAUTION — do NOT accept agent suggestions to:"
  echo "           - enable dolt.auto-start  (supervisor may overwrite it)"
  echo "           - switch to embedded mode (gc requires server mode)"
  echo "           - run 'bd dolt start' while a city is running (lock conflict)"
  echo ""
}
trap print_beads_dolt_hint EXIT

mkdir -p $SOFTWARE_FACTORY_INTENSIVE_PATH
cd $SOFTWARE_FACTORY_INTENSIVE_PATH

if gc cities | grep -q "factory"; then
  for city in $(gc cities | grep "factory" | awk '{print $2}'); do
    # Subshell so `cd` doesn't leak. `gc cities` returns absolute paths that may
    # point outside $SOFTWARE_FACTORY_INTENSIVE_PATH (stale registrations from
    # prior runs with a different .env). Leaking cwd here caused subsequent
    # rm -rf calls to nuke directories outside $SOFTWARE_FACTORY_INTENSIVE_PATH.
    (cd "$city" 2>/dev/null && gc stop) || true
  done
fi

rm -rf factory*/
rm -rf ascii-art
# Intentionally NOT removing sf-tutorial here: this script lives inside the
# sf-tutorial repo, so the user must already have it. If a future change needs
# to pin sf-tutorial to a step-specific revision, use `git fetch` + a tag
# checkout rather than delete-and-clone.

# Run 00.1-setup-foundation

# Check `gc init`, because a failure here cascades. This script has no `set -e`,
# so an unchecked failure let the `cd` below fail too and everything after it
# ran in the parent directory, and the git init/add/commit block committed
# sf-tutorial into a stray repo. Stopping at the first failure keeps the damage
# to nothing.
if ! gc init factory1 --provider $MODEL_PROVIDER; then
  echo "==> 'gc init factory1 --provider $MODEL_PROVIDER' failed." >&2
  echo "==> Nothing was created. Fix the error above, then re-run this script." >&2
  exit 1
fi
# Belt and braces: guard the cd as well, so a `gc init` that reports success
# without leaving a factory1 directory behind still stops here.
cd factory1 || exit 1

if [ $(ps aux | grep "dolt sql-server" | grep factory1 | grep -v grep | wc -l) -gt 1 ]; then
  echo "==> You have more than one Dolt process for factory1"
  echo "==> Please stop the other Dolt processes and try again."
  exit 1
fi

if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  git init -b main
  git add .
  git commit -m "00.1-setup-foundation complete"
fi

# Each step below ends the run the moment its own step is the one requested, by
# calling finish_step. That is the success path — the work is done and the city
# is up — so it exits 0, and a participant can chain
# `./bootstrap.sh <step> && <next thing>`. The `exit 1`s elsewhere in this
# script are the genuine failures: a missing dependency, a bad .env value, an
# aborted reset. Keep that split when you add a step, and end the new step with
# finish_step rather than with a banner of its own.

# How long to wait for the city to come up after `gc start`, in seconds. Raise
# it on a slow box: CITY_READY_TIMEOUT=180 ./bootstrap.sh <step>
CITY_READY_TIMEOUT="${CITY_READY_TIMEOUT:-60}"

# True once the supervisor is genuinely running this city; `gc status` prints
# the controller line only then. Pass the city path explicitly so the answer
# does not depend on which directory the calling step left us in.
city_is_up() {
  gc status "$SOFTWARE_FACTORY_INTENSIVE_PATH/factory1" 2>/dev/null | grep -q 'Controller: supervisor-managed (PID'
}

# This script runs as a child process, so the `source .env` above dies with it
# and the caller's shell comes back from a bootstrap run without
# $SOFTWARE_FACTORY_INTENSIVE_PATH set. That is what makes the rc append in W2
# write an empty value: the append succeeds, so nothing reports an error, and
# the failure only shows up a lesson later as an empty variable. Printing the
# resolved value here gives the participant something to paste.
print_reexport_block() {
  local val

  # Fall back to the raw value if the directory has gone missing.
  val="$( (cd "$SOFTWARE_FACTORY_INTENSIVE_PATH" 2>/dev/null && pwd -P) || printf '%s' "$SOFTWARE_FACTORY_INTENSIVE_PATH" )"

  echo
  echo "==> Paste this into your shell before you continue:"
  echo
  echo "export SOFTWARE_FACTORY_INTENSIVE_PATH=\"$val\""
}

# Start the city, confirm it came up, then announce the finished step. This
# exits either way, so it is the last thing a step block runs.
#
# The confirmation is the point of the function. `gc start` exits 0 even when
# startup failed, so a failed run used to print its "Ready to test" banner and
# return 0 anyway. That was reproduced twice on a fresh box with two different
# root causes, missing provider auth and an unset Dolt identity, which is why
# the check is on the city rather than on any one cause. Two signals settle it:
# the `gc start` output carries a `fatal=` field, empty on success and
# `fatal=startup-failed` on failure, and `gc status` reports the supervisor
# once the city is live. Read the first for a fast, specific error; poll the
# second to be sure.
finish_step() {
  local step="$1" start_output deadline

  start_output="$(gc start 2>&1)"
  printf '%s\n' "$start_output"

  if printf '%s' "$start_output" | grep -q 'fatal=[^[:space:]]'; then
    echo "==> 'gc start' reported a fatal error, so the city is not running." >&2
    echo "==> '$step' is NOT ready. Fix the error above, then re-run this script." >&2
    exit 1
  fi

  deadline=$((SECONDS + CITY_READY_TIMEOUT))
  while ! city_is_up; do
    if [ "$SECONDS" -ge "$deadline" ]; then
      echo "==> The city did not come up within ${CITY_READY_TIMEOUT}s of 'gc start'." >&2
      echo "==> '$step' is NOT ready. Look at what the supervisor is doing with:" >&2
      echo "==>   gc status $SOFTWARE_FACTORY_INTENSIVE_PATH/factory1" >&2
      exit 1
    fi
    sleep 2
  done

  echo "==> Ready to test on $step"

  print_reexport_block
  exit 0
}

if [ "$TUTORIAL_STEP" == "00.1-setup-foundation" ]; then
  finish_step "00.1-setup-foundation"
fi

# Run 00.2-setup-foundation

mkdir ../ascii-art
gc rig add ../ascii-art ascii-art
cd ../ascii-art
git init -b main
mkdir -p "docs/future" \
         "docs/current" \
         "docs/decision-records"
cp "$ARTIFACTS_SRC/docs/decision-records/0001.ADR.ASCII.md" \
   "docs/decision-records/"
cp "$ARTIFACTS_SRC/docs/future/0002.ADR.TESTING.md" \
   "docs/future/"
git add docs/
git commit -m "Add docs describing initial vision for ASCII Art project"
if [ "$ASCII_ART_REPO_EXISTS" == "true" ]; then
  if gh repo view "$GITHUB_USERNAME/ascii-art" >/dev/null 2>&1; then
    echo "==> ascii-art repo already exists on GitHub for $GITHUB_USERNAME; skipping create."
  else
    gh repo create $GITHUB_USERNAME/ascii-art --description "A reference project for a software factory to build." --public
  fi
fi
if [ "$GITHUB_CLONE_METHOD" == "https" ]; then
  git remote add origin https://github.com/$GITHUB_USERNAME/ascii-art.git
else
  git remote add origin git@github.com:$GITHUB_USERNAME/ascii-art.git
fi
# On a re-run, branch protection and the epic/* ruleset from a previous step 03
# are still active on the remote and will reject this push (force or not).
# Clear them now; step 03 re-applies them.
if gh repo view "$GITHUB_USERNAME/ascii-art" >/dev/null 2>&1; then
  gh api -X DELETE "repos/$GITHUB_USERNAME/ascii-art/branches/main/protection" >/dev/null 2>&1 || true
  RULESET_ID=$(gh api "repos/$GITHUB_USERNAME/ascii-art/rulesets" -q '.[] | select(.name == "Epic branches require human review") | .id' 2>/dev/null || true)
  if [[ "$RULESET_ID" =~ ^[0-9]+$ ]]; then
    gh api -X DELETE "repos/$GITHUB_USERNAME/ascii-art/rulesets/$RULESET_ID" >/dev/null 2>&1 || true
  fi
fi

if [ "$ALLOW_ASCII_ART_PUSH_FORCE" == "true" ]; then
  git push -u origin main --force
else
  git push -u origin main
fi

cd $SOFTWARE_FACTORY_INTENSIVE_PATH/factory1
mkdir -p packs
cp -r $ARTIFACTS_SRC/packs/setup/ packs/setup
chmod +x packs/setup/assets/scripts/worktree-setup.sh
# Defensive strip: cities from gc releases predating agent auto-discovery can
# carry [[agent]] tables. A no-op on current gc, which is why 00.1 no longer teaches it.
sed "${SED_I[@]}" '/^\[\[agent\]\]$/,/^$/d' pack.toml
if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  git add .
  git commit -m "00.2-setup-foundation packs"
fi
gc import add --rig ascii-art packs/setup
cd $SOFTWARE_FACTORY_INTENSIVE_PATH/ascii-art
cp "$ARTIFACTS_SRC/beads/seed-epics.sh" ./seed-epics.sh
chmod +x ./seed-epics.sh
./seed-epics.sh # You will see `Warning: auto-export: git add failed: exit status 1`, but you can ignore it.
ts=$(date +%s)
for rig_path in "$SOFTWARE_FACTORY_INTENSIVE_PATH/factory1" "$SOFTWARE_FACTORY_INTENSIVE_PATH/ascii-art"; do
  rig_name=$(basename "$rig_path")
  pre=$(cd "$rig_path" && bd config get export.auto 2>&1 || echo "<unset>")
  echo "    $rig_name export.auto (pre):  $pre"
  (cd "$rig_path" && bd config set export.auto false)
  post=$(cd "$rig_path" && bd config get export.auto 2>&1 || echo "<error>")
  echo "    $rig_name export.auto (post): $post"
  jsonl="$rig_path/.beads/issues.jsonl"
  if [ -f "$jsonl" ]; then
    backup="/tmp/${rig_name}-issues-backup-${ts}.jsonl"
    mv "$jsonl" "$backup"
    echo "    $rig_name issues.jsonl: moved to $backup"
  else
    echo "    $rig_name issues.jsonl: not present (skipping mv)"
  fi
done

if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  cd $SOFTWARE_FACTORY_INTENSIVE_PATH/factory1
  git add .
  git commit -m "00.2-setup-foundation complete"
fi

if [ "$TUTORIAL_STEP" == "00.2-setup-foundation" ]; then
  finish_step "00.2-setup-foundation"
fi

# Run 00.3-setup-foundation

if [ "$TUTORIAL_STEP" == "00.3-setup-foundation" ]; then
  finish_step "00.3-setup-foundation"
fi

# Run 01-basic-flow

cd "$SOFTWARE_FACTORY_INTENSIVE_PATH/factory1"
mkdir -p packs
cp -r $ARTIFACTS_SRC/packs/pr-gate-city/ packs/pr-gate-city
cp -r $ARTIFACTS_SRC/packs/pr-gate-rig/ packs/pr-gate-rig
if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  # packs/ is not gitignored, so a plain add stages it. gc import add needs the
  # pack committed at HEAD before it can resolve a path inside a git worktree.
  git add .
  git commit -m "01-basic-flow packs"
fi
gc import add packs/pr-gate-city
gc import add --rig ascii-art packs/pr-gate-rig
gc import remove --rig ascii-art setup
rm -rf "$SOFTWARE_FACTORY_INTENSIVE_PATH/factory1/agents/mayor"
# Point the always-on mayor session at the pack's mayor. Deleting the block
# outright would leave the city with no mayor at all, because pr-gate-city
# deliberately declares no named_session of its own.
sed '/^\[\[named_session\]\]/,/^[[:space:]]*mode = /d' "$SOFTWARE_FACTORY_INTENSIVE_PATH/factory1/pack.toml" > "$SOFTWARE_FACTORY_INTENSIVE_PATH/factory1/pack.toml.tmp"
cat >> "$SOFTWARE_FACTORY_INTENSIVE_PATH/factory1/pack.toml.tmp" <<'EOF'
[[named_session]]
name = "mayor"
template = "pr-gate-city.mayor"
mode = "always"
EOF
mv "$SOFTWARE_FACTORY_INTENSIVE_PATH/factory1/pack.toml.tmp" "$SOFTWARE_FACTORY_INTENSIVE_PATH/factory1/pack.toml"

if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  git add .
  git commit -m "01-basic-flow complete"
fi

if [ "$TUTORIAL_STEP" == "01-basic-flow" ]; then
  finish_step "01-basic-flow"
fi

# Run 02-first-review-loop

cd $SOFTWARE_FACTORY_INTENSIVE_PATH/factory1
mkdir -p packs
cp -r $ARTIFACTS_SRC/packs/review-loop-rig/ packs/review-loop-rig
if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  git add .
  git commit -m "02-first-review-loop packs"
fi
gc import add --rig ascii-art packs/review-loop-rig
gc import remove --rig ascii-art pr-gate-rig

if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  git add .
  git commit -m "02-first-review-loop complete"
fi

if [ "$TUTORIAL_STEP" == "02-first-review-loop" ]; then
  finish_step "02-first-review-loop"
fi

# Run 03-branch-protection

cd $SOFTWARE_FACTORY_INTENSIVE_PATH/ascii-art
mkdir -p .github
cp $ARTIFACTS_SRC/github/CODEOWNERS \
  .github/CODEOWNERS
# Double quotes so $GITHUB_USERNAME expands, and keep the leading @ — an owner
# without it is not a valid CODEOWNERS entry and silently matches nobody.
sed "${SED_I[@]}" "s/@your-github-handle/@$GITHUB_USERNAME/g" .github/CODEOWNERS
git add .github/CODEOWNERS
git commit -m "chore: add CODEOWNERS"
git push origin main
# Assert the pushed file names the handle, not merely that the path exists.
if ! gh api "repos/$GITHUB_USERNAME/ascii-art/contents/.github/CODEOWNERS" \
     -H "Accept: application/vnd.github.raw" | grep -q "^\*[[:space:]]*@$GITHUB_USERNAME$"; then
  echo "==> CODEOWNERS on main does not name @$GITHUB_USERNAME as the default owner." >&2
  echo "==> Branch protection would block every merge with no reviewer able to approve." >&2
  exit 1
fi
OWNER=$GITHUB_USERNAME REPO=ascii-art $ARTIFACTS_SRC/github/branch-protection.sh

if [ "$TUTORIAL_STEP" == "03-branch-protection" ]; then
  finish_step "03-branch-protection"
fi

# Run 04-adr-reviewer

cd $SOFTWARE_FACTORY_INTENSIVE_PATH/factory1
mkdir -p packs
cp -r $ARTIFACTS_SRC/packs/architect-rig/ packs/architect-rig
if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  git add .
  git commit -m "04-adr-reviewer packs"
fi
gc import add --rig ascii-art packs/architect-rig
gc import remove --rig ascii-art review-loop-rig

if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  git add .
  git commit -m "04-adr-reviewer complete"
fi

if [ "$TUTORIAL_STEP" == "04-adr-reviewer" ]; then
  finish_step "04-adr-reviewer"
fi

# Run 05.1-bead-gate-checks

cd $SOFTWARE_FACTORY_INTENSIVE_PATH/factory1
mkdir -p packs
cp -r $ARTIFACTS_SRC/packs/bead-gate-rig/ packs/bead-gate-rig
if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  git add .
  git commit -m "05.1-bead-gate-checks packs"
fi
gc import add --rig ascii-art packs/bead-gate-rig
gc import remove --rig ascii-art architect-rig

if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  git add .
  git commit -m "05.1-bead-gate-checks complete"
fi

if [ "$TUTORIAL_STEP" == "05.1-bead-gate-checks" ]; then
  finish_step "05.1-bead-gate-checks"
fi

# Run 05.2-bead-gate-checks

if [ ! -d $SOFTWARE_FACTORY_INTENSIVE_PATH/mp-skills ]; then
  if [ "$GITHUB_CLONE_METHOD" == "https" ]; then
    git clone https://github.com/mattpocock/skills.git $SOFTWARE_FACTORY_INTENSIVE_PATH/mp-skills
  elif [ "$GITHUB_CLONE_METHOD" == "ssh" ]; then
    git clone git@github.com:mattpocock/skills.git $SOFTWARE_FACTORY_INTENSIVE_PATH/mp-skills
  elif [ "$GITHUB_CLONE_METHOD" == "gh" ]; then
    gh repo clone mattpocock/skills $SOFTWARE_FACTORY_INTENSIVE_PATH/mp-skills
  else
    echo "==> GITHUB_CLONE_METHOD environment variable is not valid"
    echo "==> Please set the GITHUB_CLONE_METHOD environment variable to a valid value (https, ssh, gh)."
    exit 1
  fi
fi
cd "$SOFTWARE_FACTORY_INTENSIVE_PATH/ascii-art"
mkdir -p .claude/skills/grill-me
if [ ! -f .claude/skills/grill-me/SKILL.md ]; then
  cp $SOFTWARE_FACTORY_INTENSIVE_PATH/mp-skills/skills/productivity/grill-me/SKILL.md \
     .claude/skills/grill-me/SKILL.md
fi

if [ "$TUTORIAL_STEP" == "05.2-bead-gate-checks" ]; then
  finish_step "05.2-bead-gate-checks"
fi
