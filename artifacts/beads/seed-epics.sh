#!/usr/bin/env bash
# seed-epics.sh
# ----------------------------------------------------------------------------
# Seeds the ASCII Factory rig with 2 epics and 26 child tasks (28 beads).
#
# What this opens:
#   - 2 epic beads (Letters a–m, Letters n–z)
#   - 26 letter tasks  (a.md ... z.md, split across the two letter epics)
#
# Each child task is parented to its epic (--parent <epic-id>) and stamped
# with metadata.target_file = "ascii/<filename>" plus a concrete description
# so downstream tools and agents can locate and validate the artifact.
#
# Run this AFTER `bd init` in your rig root, BEFORE handing work to agents:
#   chmod +x seed-epics.sh
#   ./seed-epics.sh
# ----------------------------------------------------------------------------

set -euo pipefail

# --- preflight ---------------------------------------------------------------

# Require bd and jq (jq plucks the epic id from --json output).
for tool in bd jq; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "error: '${tool}' not found on PATH. Install it and re-run." >&2
    exit 1
  fi
done

# Idempotency guard: if the first epic title already exists, bail out.
# Coarse on purpose — we refuse to double-seed rather than dedupe per-bead.
#
# `bd search` always echoes the search term in its "No issues found
# matching '<term>'" message, so plain `grep -q` would false-positive
# on every empty db. Use --json + jq length instead.
if [ "$(bd search "Letters a–m" --json 2>/dev/null | jq 'length')" -gt 0 ]; then
  echo "Looks like 'Letters a–m' already exists in this beads db." >&2
  echo "Seed appears to have run. Aborting to avoid duplicates." >&2
  echo "To reseed, clear the db first (rm -rf .beads && bd init)." >&2
  exit 1
fi

# --- helpers -----------------------------------------------------------------

# create_epic <title> <epic-slug>
# Creates one epic bead, returns its bead id on stdout.
create_epic() {
  local title="$1"
  local slug="$2"
  bd create \
    --type=epic \
    --priority=2 \
    --metadata "{\"epic\":\"${slug}\"}" \
    --json \
    "${title}" \
  | jq -r .id
}

# create_child <epic-id> <filename>  (e.g. create_child bd-12 a.md)
# Creates one child task bead under the given epic, stamped with target_file.
create_child() {
  local parent="$1"
  local fname="$2"
  bd create \
    --type=task \
    --parent="${parent}" \
    --priority=2 \
    --metadata "{\"target_file\":\"ascii/${fname}\"}" \
    --description "Create ascii/${fname} for '${fname%.md}' with one printable-ASCII text block no larger than 8 lines by 20 columns and a two-line rhyme, following docs/decision-records/0001.ADR.ASCII.md." \
    --silent \
    "Implement ${fname}" \
  >/dev/null
}

# seed_letter_epic <title> <slug> <start-letter> <end-letter>
seed_letter_epic() {
  local title="$1" slug="$2" start="$3" end="$4"
  echo "==> creating epic: ${title}"
  local epic_id; epic_id="$(create_epic "${title}" "${slug}")"
  echo "    epic id: ${epic_id}"
  local count=0
  # shellcheck disable=SC2046  # brace expansion is fine here
  for c in $(eval echo {${start}..${end}}); do
    create_child "${epic_id}" "${c}.md"
    count=$((count + 1))
  done
  echo "    opened ${count} child task(s)"
  TOTAL_TASKS=$((TOTAL_TASKS + count))
}

# --- run ---------------------------------------------------------------------

TOTAL_EPICS=2
TOTAL_TASKS=0

# Two letter epics (a–m = 13, n–z = 13).
seed_letter_epic "Letters a–m" "letters-a-m" "a" "m"
seed_letter_epic "Letters n–z" "letters-n-z" "n" "z"

# --- summary -----------------------------------------------------------------

echo
echo "Seed complete."
echo "  epics opened: ${TOTAL_EPICS}"
echo "  tasks opened: ${TOTAL_TASKS}"
echo "  total beads:  $((TOTAL_EPICS + TOTAL_TASKS))"
echo
echo "Next steps:"
echo "  bd list --type=epic                     # see the 2 epics"
echo "  bd ready                                # find a task to start on"
echo "  gc sling ascii-art/polecat <bead-id>    # hand a task to an agent"
