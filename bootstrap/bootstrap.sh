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

if [ -z "$BD_PINNED" ] || [ -z "$DOLT_PINNED" ]; then
  echo "==> Could not read the pinned versions from ${HERE}/deps.sh"
  echo "==> Expected BD_VERSION and DOLT_VERSION to be declared there."
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
  echo "==> Please install gc."
  exit 1
fi

gc_version=$(gc version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [ "$gc_version" != "1.1.0" ]; then
  echo "==> gc is not on the correct version (found: ${gc_version:-unknown})"
  echo "==> Please install gc 1.1.0."
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

export TUTORIAL_PATH="$(pwd)/.."
export ARTIFACTS_PATH="$TUTORIAL_PATH/artifacts"

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
DERIVED_SFI_PATH="$(cd "$TUTORIAL_PATH/.." && pwd -P)"
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

gc init factory1 --provider $MODEL_PROVIDER
cd factory1

export FACTORY_PATH="$(pwd)"

if [ $(ps aux | grep "dolt sql-server" | grep factory1 | grep -v grep | wc -l) -gt 1 ]; then
  echo "==> You have more than one Dolt process for factory1"
  echo "==> Please stop the other Dolt processes and try again."
  exit 1
fi

if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  git init -b main
  git add .
  git add -f .gc/system/
  git commit -m "00.1-setup-foundation complete"
fi

if [ "$TUTORIAL_STEP" == "00.1-setup-foundation" ]; then
  gc start
  echo "==> Ready to test on 00.1-setup-foundation"
  exit 1
fi

# Run 00.2-setup-foundation

mkdir ../ascii-art
gc rig add ../ascii-art ascii-art
cd ../ascii-art
export ASCII_ART_PATH="$(pwd)"
git init -b main
mkdir -p "docs/future" \
         "docs/current" \
         "docs/decision-records"
cp "$ARTIFACTS_PATH/docs/decision-records/0001.ADR.ASCII.md" \
   "docs/decision-records/"
cp "$ARTIFACTS_PATH/docs/future/0002.ADR.TESTING.md" \
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

cd $FACTORY_PATH
cp -r $ARTIFACTS_PATH/packs/setup/ .gc/system/packs/setup
chmod +x .gc/system/packs/setup/assets/scripts/worktree-setup.sh
sed "${SED_I[@]}" '/^\[\[agent\]\]$/,/^$/d' pack.toml
if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  git add -f .gc/system/
  git add .
  git commit -m "00.2-setup-foundation packs"
fi
gc import add --rig ascii-art .gc/system/packs/setup
cd $ASCII_ART_PATH
cp "$ARTIFACTS_PATH/beads/seed-epics.sh" ./seed-epics.sh
chmod +x ./seed-epics.sh
./seed-epics.sh # You will see `Warning: auto-export: git add failed: exit status 1`, but you can ignore it.
ts=$(date +%s)
for rig_path in "$FACTORY_PATH" "$ASCII_ART_PATH"; do
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
  cd $FACTORY_PATH
  git add .
  git commit -m "00.2-setup-foundation complete"
fi

if [ "$TUTORIAL_STEP" == "00.2-setup-foundation" ]; then
  gc start
  echo "==> Ready to test on 00.2-setup-foundation"
exit 1
fi

# Run 00.3-setup-foundation

if [ "$TUTORIAL_STEP" == "00.3-setup-foundation" ]; then
  gc start
  echo "==> Ready to test on 00.3-setup-foundation"
exit 1
fi

# Run 01-basic-flow

cd "$FACTORY_PATH"
cp -r $ARTIFACTS_PATH/packs/pr-gate-city/ .gc/system/packs/pr-gate-city
cp -r $ARTIFACTS_PATH/packs/pr-gate-rig/ .gc/system/packs/pr-gate-rig
if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  git add -f .gc/system/
  git commit -m "01-basic-flow packs"
fi
gc import add .gc/system/packs/pr-gate-city
gc import add --rig ascii-art .gc/system/packs/pr-gate-rig
gc import remove --rig ascii-art setup
rm -rf "$FACTORY_PATH/agents/mayor"
sed "${SED_I[@]}" '/\[named_session\]/,/\[named_session\]/d' "$FACTORY_PATH/pack.toml"

if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  git add .
  git commit -m "01-basic-flow complete"
fi

if [ "$TUTORIAL_STEP" == "01-basic-flow" ]; then
  gc start
  echo "==> Ready to test on 01-basic-flow"
exit 1
fi

# Run 02-first-review-loop

cd $FACTORY_PATH
cp -r $ARTIFACTS_PATH/packs/review-loop-rig/ .gc/system/packs/review-loop-rig
if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  git add -f .gc/system/
  git commit -m "02-first-review-loop packs"
fi
gc import add --rig ascii-art .gc/system/packs/review-loop-rig
gc import remove --rig ascii-art pr-gate-rig

if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  git add .
  git commit -m "02-first-review-loop complete"
fi

if [ "$TUTORIAL_STEP" == "02-first-review-loop" ]; then
  gc start
  echo "==> Ready to test on 02-first-review-loop"
exit 1
fi

# Run 03-branch-protection

cd $ASCII_ART_PATH
mkdir -p .github
cp $ARTIFACTS_PATH/github/CODEOWNERS \
  .github/CODEOWNERS
sed "${SED_I[@]}" 's/@your-github-handle/$GITHUB_USERNAME/g' .github/CODEOWNERS
git add .github/CODEOWNERS
git commit -m "chore: add CODEOWNERS"
git push origin main
gh api "repos/$GITHUB_USERNAME/ascii-art/contents/.github/CODEOWNERS" -q '.path'
OWNER=$GITHUB_USERNAME REPO=ascii-art $ARTIFACTS_PATH/github/branch-protection.sh

if [ "$TUTORIAL_STEP" == "03-branch-protection" ]; then
  gc start
  echo "==> Ready to test on 03-branch-protection"
exit 1
fi

# Run 04-adr-reviewer

cd $FACTORY_PATH
cp -r $ARTIFACTS_PATH/packs/architect-rig/ .gc/system/packs/architect-rig
if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  git add -f .gc/system/
  git commit -m "04-adr-reviewer packs"
fi
gc import add --rig ascii-art .gc/system/packs/architect-rig
gc import remove --rig ascii-art review-loop-rig

if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  git add .
  git commit -m "04-adr-reviewer complete"
fi

if [ "$TUTORIAL_STEP" == "04-adr-reviewer" ]; then
  gc start
  echo "==> Ready to test on 04-adr-reviewer"
exit 1
fi

# Run 05.1-bead-gate-checks

cd $FACTORY_PATH
cp -r $ARTIFACTS_PATH/packs/bead-gate-rig/ .gc/system/packs/bead-gate-rig
if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  git add -f .gc/system/
  git commit -m "05.1-bead-gate-checks packs"
fi
gc import add --rig ascii-art .gc/system/packs/bead-gate-rig
gc import remove --rig ascii-art architect-rig

if [ "$FACTORY_VERSION_CONTROL" == "true" ]; then
  git add .
  git commit -m "05.1-bead-gate-checks complete"
fi

if [ "$TUTORIAL_STEP" == "05.1-bead-gate-checks" ]; then
  gc start
  echo "==> Ready to test on 05.1-bead-gate-checks"
exit 1
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
cd "$ASCII_ART_PATH"
mkdir -p .claude/skills/grill-me
if [ ! -f .claude/skills/grill-me/SKILL.md ]; then
  cp $SOFTWARE_FACTORY_INTENSIVE_PATH/mp-skills/skills/productivity/grill-me/SKILL.md \
     .claude/skills/grill-me/SKILL.md
fi

if [ "$TUTORIAL_STEP" == "05.2-bead-gate-checks" ]; then
  gc start
  echo "==> Ready to test on 05.2-bead-gate-checks"
exit 1
fi
