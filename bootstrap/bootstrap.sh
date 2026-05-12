#!/usr/bin/env bash

# Capture the tutorial step from the first positional argument.
TUTORIAL_STEP="$1"

if [ -z "$TUTORIAL_STEP" ]; then
  echo "==> Usage: ./bootstrap.sh <TUTORIAL_STEP>"
  echo "==> Please pass the tutorial step as the first argument."
  exit 1
fi

# Give the user a Y/n prompt to confirm they are comfortable with
# with resettng the associated files/folders in this script.

read -p "Are you comfortable with resetting all of \$SOFTWARE_FACTORY_INTENSIVE_PATH? (Y/n) " confirm
if [ "$confirm" != "Y" ]; then
  echo "==> Exiting script."
  exit 1
fi

echo "==> Continuing script."

# Prerequisites:

# 1. ~/software-factory-intensive (or the value of SOFTWARE_FACTORY_INTENSIVE_PATH in the .env file) is a directory
# ```bash
# export SOFTWARE_FACTORY_INTENSIVE_PATH=~/software-factory-intensive
# mkdir -p $SOFTWARE_FACTORY_INTENSIVE_PATH
# ```

# 2. https://github.com/actual-software/sf-tutorial.git is cloned in ~/software-factory-intensive/sf-tutorial
# ```bash
# cd $SOFTWARE_FACTORY_INTENSIVE_PATH
# git clone https://github.com/actual-software/sf-tutorial.git
# ```

# 3. bootstrap.sh has been made executable
# ```bash
# chmod +x bootstrap.sh
# ```

# 4. bd is installaed on the correct version
# MacOS Installation:
# ```bash
# brew install bd
# ```

# Linux Installation:
# curl -fsSL https://raw.githubusercontent.com/bd-ls/bd/main/install.sh | bash
# ```

# 5. bd is on the correct version

# Check if bd is installed on the correct version
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

# 6. gc is installed on the correct version

# Check if gc is installed
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

# 7. dolt is installed on the correct version
# ```bash
# dolt version
# ```

# Check if dolt is installed
if ! command -v dolt &> /dev/null; then
  echo "==> dolt could not be found"
  echo "==> Please install dolt."
  exit 1
fi

dolt_version=$(dolt version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [[ "$dolt_version" != "1.8.8" ]]; then
  echo "==> dolt is not on the correct version (found: ${dolt_version:-unknown})"
  echo "==> Please install dolt 1.8.8."
  exit 1
fi

# Check if the .env file exists and is populated
if [ ! -f .env ]; then
  echo "==> .env file not found"
  echo "==> Please create a .env file in this folder with the correct values."
  exit 1
fi

# Initial Setup:

## Source the .env file
source .env

## Export current directory as TUTORIAL_PATH
export TUTORIAL_PATH="$(pwd)/.."
export ARTIFACTS_PATH="$TUTORIAL_PATH/artifacts"

## Remove file extension from the TUTORIAL_STEP argument
TUTORIAL_STEP=$(echo "$TUTORIAL_STEP" | sed 's/\.md$//')

## Check if the TUTORIAL_STEP argument is valid
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

## Check if the MODEL_PROVIDER environment variable is set
if [ -z "$MODEL_PROVIDER" ]; then
  echo "==> MODEL_PROVIDER environment variable not found"
  echo "==> Please set the MODEL_PROVIDER environment variable in the .env file."
  exit 1
fi

## Check if the MODEL_PROVIDER environment variable is valid
if ! [[ "$MODEL_PROVIDER" =~ ^(claude|codex|gemini)$ ]]; then
  echo "==> MODEL_PROVIDER environment variable is not valid"
  echo "==> Please set the MODEL_PROVIDER environment variable to a valid value (claude, codex, gemini)."
  exit 1
fi

## Check if the GITHUB_USERNAME environment variable is set
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

## Check if the ALLOW_ASCII_ART_PUSH_FORCE environment variable is set
if [ -z "$ALLOW_ASCII_ART_PUSH_FORCE" ]; then
  echo "==> ALLOW_ASCII_ART_PUSH_FORCE environment variable not found"
  echo "==> Please set the ALLOW_ASCII_ART_PUSH_FORCE environment variable in the .env file."
  exit 1
fi

## Check if the ALLOW_ASCII_ART_PUSH_FORCE environment variable is valid
if ! [[ "$ALLOW_ASCII_ART_PUSH_FORCE" =~ ^(true|false)$ ]]; then
  echo "==> ALLOW_ASCII_ART_PUSH_FORCE environment variable is not valid"
  echo "==> Please set the ALLOW_ASCII_ART_PUSH_FORCE environment variable to a valid value (true, false)."
  exit 1
fi

## Check that no gas cities are running
if gc cities | grep -q "factory"; then
  for city in $(gc cities | grep "factory" | awk '{print $2}'); do
    cd $city
    gc stop
    cd ..
  done
fi

## Delete all existing directories
cd $SOFTWARE_FACTORY_INTENSIVE_PATH/
rm -rf factory*/
rm -rf ascii-art
rm -rf sf-tutorial

# Run 00.1-setup-foundation
gc init factory1 --provider $MODEL_PROVIDER
cd factory1
export FACTORY_PATH="$(pwd)"
sed -i '' '/^\[\[agent\]\]$/,/^$/d' $FACTORY_PATH/pack.toml
gc import add ../sf-tutorial/artifacts/packs/setup
chmod +x .gc/system/packs/setup/assets/scripts/worktree-setup.sh
gc start
if [ $(ps aux | grep "dolt sql-server" | grep factory1 | grep -v grep | wc -l) -gt 1 ]; then
  echo "==> You have more than one Dolt process for factory1"
  echo "==> Please stop the other Dolt processes and try again."
  exit 1
fi

if [ "$TUTORIAL_STEP" == "00.1-setup-foundation" ]; then
  echo "==> Ready to start on 00.2-setup-foundation"
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
gh repo create $GITHUB_USERNAME/ascii-art --description "A reference project for a software factory to build." --public
fi
git remote add origin https://github.com/$GITHUB_USERNAME/ascii-art.git
if [ "$ALLOW_ASCII_ART_PUSH_FORCE" == "true" ]; then
  git push -u origin main --force
else
  git push -u origin main
fi
cp -r "$ARTIFACTS_PATH/packs/setup" \
      "$FACTORY_PATH/.gc/system/packs/setup"
cd $FACTORY_PATH
gc import add --rig ascii-art .gc/system/packs/setup
gc import list --rig ascii-art
gc restart
cd $ASCII_ART_PATH
cp "$ARTIFACTS_PATH/beads/seed-epics.sh" ./seed-epics.sh
chmod +x ./seed-epics.sh
./seed-epics.sh

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
  echo "==> Ready to start on 00.2-setup-foundation"
exit 1
fi
