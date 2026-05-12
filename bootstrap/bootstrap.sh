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
if [[ "$bd_version" != "1.0.3" ]]; then
  echo "==> bd is not on the correct version (found: ${bd_version:-unknown})"
  echo "==> Please install bd 1.0.3."
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
if [[ "$dolt_version" != "2.0.1" ]]; then
  echo "==> dolt is not on the correct version (found: ${dolt_version:-unknown})"
  echo "==> Please install dolt 2.0.1."
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

# Hint printed on script exit. Defined after env validation so it doesn't
# fire for runs that bailed before beads/dolt setup was relevant.
print_beads_dolt_hint() {
  echo ""
  echo "==> Heads-up: beads/Dolt troubleshooting"
  echo "    gc's supervisor manages Dolt per rig in SERVER mode. If you hit"
  echo "    'Dolt server unreachable' or 'failed to open database':"
  echo ""
  echo "      1. Use Claude Code (or another agent) to investigate and fix."
  echo "      2. CAUTION — do NOT accept suggestions to:"
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
sed "${SED_I[@]}" '/^\[\[agent\]\]$/,/^$/d' $FACTORY_PATH/pack.toml
if [ $(ps aux | grep "dolt sql-server" | grep factory1 | grep -v grep | wc -l) -gt 1 ]; then
  echo "==> You have more than one Dolt process for factory1"
  echo "==> Please stop the other Dolt processes and try again."
  exit 1
fi

if [ "$TUTORIAL_STEP" == "00.1-setup-foundation" ]; then
  gc start
  echo "==> Ready to test on 00.1-setup-foundation"
exit 1
fi

# Run 00.2-setup-foundation

mkdir ../ascii-art
gc rig add ../ascii-art ascii-art
export ASCII_ART_PATH="$(cd ../ascii-art && pwd)"
mkdir -p "$ASCII_ART_PATH/docs/future" \
         "$ASCII_ART_PATH/docs/current" \
         "$ASCII_ART_PATH/docs/decision-records"
cp "$ARTIFACTS_PATH/docs/decision-records/0001.ADR.ASCII.md" \
   "$ASCII_ART_PATH/docs/decision-records/"
cp "$ARTIFACTS_PATH/docs/future/0002.ADR.TESTING.md" \
   "$ASCII_ART_PATH/docs/future/"
cd "$ASCII_ART_PATH"
git init -b main
git commit --allow-empty -m 'first commit'
git add docs/ .gitignore
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
cp -r "$ARTIFACTS_PATH/packs/setup" \
      "$FACTORY_PATH/.gc/system/packs/setup"
cd $FACTORY_PATH
chmod +x .gc/system/packs/setup/assets/scripts/worktree-setup.sh
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

cp -r "$ARTIFACTS_PATH/packs/pr-gate-city" \
      "$FACTORY_PATH/.gc/system/packs/pr-gate-city"
cp -r "$ARTIFACTS_PATH/packs/pr-gate-rig" \
      "$FACTORY_PATH/.gc/system/packs/pr-gate-rig"
cd "$FACTORY_PATH"
gc import add .gc/system/packs/pr-gate-city
gc import add --rig ascii-art .gc/system/packs/pr-gate-rig
gc import remove --rig ascii-art setup
rm -rf "$FACTORY_PATH/agents/mayor"
sed "${SED_I[@]}" '/\[named_session\]/,/\[named_session\]/d' "$FACTORY_PATH/pack.toml"

if [ "$TUTORIAL_STEP" == "01-basic-flow" ]; then
  gc start
  echo "==> Ready to test on 01-basic-flow"
exit 1
fi

# Run 02-first-review-loop

cp -r "$ARTIFACTS_PATH/packs/review-loop-rig" \
      "$FACTORY_PATH/.gc/system/packs/review-loop-rig"
cd "$FACTORY_PATH"
gc import add --rig ascii-art .gc/system/packs/review-loop-rig
gc import remove --rig ascii-art pr-gate-rig

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

cp -r "$ARTIFACTS_PATH/packs/architect-rig" \
      "$FACTORY_PATH/.gc/system/packs/architect-rig"
cd "$FACTORY_PATH"
gc import add --rig ascii-art .gc/system/packs/architect-rig
gc import remove --rig ascii-art review-loop-rig

if [ "$TUTORIAL_STEP" == "04-adr-reviewer" ]; then
  gc start
  echo "==> Ready to test on 04-adr-reviewer"
exit 1
fi

# Run 05.1-bead-gate-checks

cp -r "$ARTIFACTS_PATH/packs/bead-gate-rig" \
      "$FACTORY_PATH/.gc/system/packs/bead-gate-rig"
cd "$FACTORY_PATH"
gc import add --rig ascii-art .gc/system/packs/bead-gate-rig
gc import remove --rig ascii-art architect-rig

if [ "$TUTORIAL_STEP" == "05.1-bead-gate-checks" ]; then
  gc start
  echo "==> Ready to test on 05.1-bead-gate-checks"
exit 1
fi

# Run 05.2-bead-gate-checks

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
cd "$ASCII_ART_PATH"
mkdir -p .claude/skills/grill-me
cp $SOFTWARE_FACTORY_INTENSIVE_PATH/mp-skills/skills/productivity/grill-me/SKILL.md \
   .claude/skills/grill-me/SKILL.md

if [ "$TUTORIAL_STEP" == "05.2-bead-gate-checks" ]; then
  gc start
  echo "==> Ready to test on 05.2-bead-gate-checks"
exit 1
fi
