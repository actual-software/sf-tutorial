#!/usr/bin/env bash
# seed-epics.sh
# ----------------------------------------------------------------------------
# Seeds the ASCII Factory rig with 12 epics and 126 child tasks (138 beads).
#
# What this opens:
#   - 12 epic beads (Letters a–m, Letters n–z, Numbers 1–10 ... Numbers 91–100)
#   - 26 letter tasks  (a.md ... z.md, split across the two letter epics)
#   - 100 number tasks (1.md ... 100.md, split across the ten number epics)
#
# Each child task is parented to its epic (--parent <epic-id>) and stamped
# with metadata.target_file = "ascii/<filename>" so downstream tools and
# agents can locate the artifact path without parsing the title.
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

# seed_number_epic <title> <slug> <start-num> <end-num>
seed_number_epic() {
  local title="$1" slug="$2" start="$3" end="$4"
  echo "==> creating epic: ${title}"
  local epic_id; epic_id="$(create_epic "${title}" "${slug}")"
  echo "    epic id: ${epic_id}"
  local count=0
  for n in $(seq "${start}" "${end}"); do
    create_child "${epic_id}" "${n}.md"
    count=$((count + 1))
  done
  echo "    opened ${count} child task(s)"
  TOTAL_TASKS=$((TOTAL_TASKS + count))
}

# --- run ---------------------------------------------------------------------

TOTAL_EPICS=12
TOTAL_TASKS=0

# Two letter epics (a–m = 13, n–z = 13).
seed_letter_epic "Letters a–m" "letters-a-m" "a" "m"
seed_letter_epic "Letters n–z" "letters-n-z" "n" "z"

# Ten number epics, ten beads each.
# seed_number_epic "Numbers 1–10"   "numbers-1-10"     1  10
# seed_number_epic "Numbers 11–20"  "numbers-11-20"   11  20
# seed_number_epic "Numbers 21–30"  "numbers-21-30"   21  30
# seed_number_epic "Numbers 31–40"  "numbers-31-40"   31  40
# seed_number_epic "Numbers 41–50"  "numbers-41-50"   41  50
# seed_number_epic "Numbers 51–60"  "numbers-51-60"   51  60
# seed_number_epic "Numbers 61–70"  "numbers-61-70"   61  70
# seed_number_epic "Numbers 71–80"  "numbers-71-80"   71  80
# seed_number_epic "Numbers 81–90"  "numbers-81-90"   81  90
# seed_number_epic "Numbers 91–100" "numbers-91-100"  91 100

# --- summary -----------------------------------------------------------------

echo
echo "Seed complete."
echo "  epics opened: ${TOTAL_EPICS}"
echo "  tasks opened: ${TOTAL_TASKS}"
echo "  total beads:  $((TOTAL_EPICS + TOTAL_TASKS))"
echo
echo "Next steps:"
echo "  bd list --type=epic                     # see the 12 epics"
echo "  bd ready                                # find a task to start on"
echo "  gc sling ascii-art/polecat <bead-id>    # hand a task to an agent"
