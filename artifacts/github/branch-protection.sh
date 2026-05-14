#!/usr/bin/env bash
# branch-protection.sh — install GitHub branch protection per REFINERY.md §2.
#
# Two API operations, both idempotent (re-running this script is safe):
#   1. PUT  repos/<owner>/<repo>/branches/main/protection  (single branch upsert)
#   2. POST repos/<owner>/<repo>/rulesets                  (pattern epic/*; PUT
#      to update if a ruleset of the same name already exists)
#
# Usage:
#   OWNER=acme REPO=widgets ./branch-protection.sh
#   OWNER=acme REPO=widgets MIN_APPROVALS=2 STATUS_CHECKS="ci/build,ci/test" ./branch-protection.sh
#   OWNER=acme REPO=widgets DRY_RUN=1 ./branch-protection.sh   # print, don't execute
set -euo pipefail

# ---- Config (env vars) ----------------------------------------------------
OWNER="${OWNER:-}"                  # required: GitHub org/user
REPO="${REPO:-}"                    # required: repo name
MIN_APPROVALS="${MIN_APPROVALS:-1}" # default 1; later pages may raise this
STATUS_CHECKS="${STATUS_CHECKS:-}"  # comma-separated; empty = no required CI yet
DRY_RUN="${DRY_RUN:-0}"             # 1 = print commands, don't execute

[ -z "$OWNER" ] && { echo "ERROR: OWNER env var is required (e.g. OWNER=acme)"; exit 2; }
[ -z "$REPO"  ] && { echo "ERROR: REPO env var is required (e.g. REPO=widgets)"; exit 2; }

# ---- Pre-flight -----------------------------------------------------------
# `gh` must be installed and authenticated; without these the API calls
# below fail with opaque 401s. Fail fast with a clearer message.
command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI not installed (https://cli.github.com)"; exit 3; }
gh auth status >/dev/null 2>&1   || { echo "ERROR: gh not authenticated. Run: gh auth login"; exit 3; }

# Branch protection requires admin on the repo. Tolerate empty (older API
# responses) and only block on explicit "false".
ADMIN=$(gh api "repos/$OWNER/$REPO" -q .permissions.admin 2>/dev/null || echo "")
[ "$ADMIN" = "false" ] && { echo "ERROR: no admin permission on $OWNER/$REPO"; exit 4; }

# DRY_RUN gating; echoes to stderr so it survives `>/dev/null` on real runs.
run() { if [ "$DRY_RUN" = "1" ]; then echo "[DRY_RUN] $*" >&2; else "$@"; fi; }

# ---- 1. Protect `main` ----------------------------------------------------
# Build a positional `-F field=value` arg list. Required-status-checks is
# only added when STATUS_CHECKS is non-empty: page 03 runs before any CI
# is wired, so demanding a non-existent check would block every merge.
# `enforce_admins=true` is what makes the gate real: with it false, repo
# admins (i.e. the rig owner running the polecat) can `git push` straight
# to main and GitHub records "Bypassed rule violations" instead of
# rejecting. The whole point of this page is that direct merges are gone.
echo ">> Applying branch protection on main ($OWNER/$REPO)"

MAIN_ARGS=(
  -X PUT "repos/$OWNER/$REPO/branches/main/protection"
  -F "required_pull_request_reviews[required_approving_review_count]=$MIN_APPROVALS"
  -F "required_pull_request_reviews[require_code_owner_reviews]=true"
  -F "required_pull_request_reviews[dismiss_stale_reviews]=true"
  -F "enforce_admins=true"
  -F "restrictions=null"
  -F "allow_force_pushes=false"
  -F "allow_deletions=false"
)

if [ -n "$STATUS_CHECKS" ]; then
  MAIN_ARGS+=( -F "required_status_checks[strict]=true" )
  IFS=',' read -ra CHECKS <<< "$STATUS_CHECKS"
  for c in "${CHECKS[@]}"; do
    c="${c#"${c%%[![:space:]]*}"}"; c="${c%"${c##*[![:space:]]}"}" # trim
    [ -n "$c" ] && MAIN_ARGS+=( -F "required_status_checks[contexts][]=$c" )
  done
else
  # API requires the field even when there are no checks; send explicit null.
  MAIN_ARGS+=( -F "required_status_checks=null" )
  echo "   (no STATUS_CHECKS set — required_status_checks=null)"
fi

run gh api "${MAIN_ARGS[@]}" >/dev/null
echo "   main: protection applied"

# ---- 2. Protect epic/* via a ruleset --------------------------------------
# Branch-protection rules apply to EXACT branch names; the `epic/*` pattern
# requires a repository ruleset. POST a new one, or PUT an update if a
# ruleset of the same name already exists (idempotency).
RULESET_NAME="Epic branches require human review"
echo ">> Applying ruleset for epic/* ($RULESET_NAME)"
STATUS_RULE=""  # required_status_checks rule fragment, built when STATUS_CHECKS set
if [ -n "$STATUS_CHECKS" ]; then
  IFS=',' read -ra CHECKS <<< "$STATUS_CHECKS"
  CTX_JSON=""
  for c in "${CHECKS[@]}"; do
    c="${c#"${c%%[![:space:]]*}"}"; c="${c%"${c##*[![:space:]]}"}"
    [ -z "$c" ] && continue
    [ -n "$CTX_JSON" ] && CTX_JSON="$CTX_JSON,"
    CTX_JSON="$CTX_JSON{\"context\":\"$c\"}"
  done
  STATUS_RULE=",{\"type\":\"required_status_checks\",\"parameters\":{\"required_status_checks\":[$CTX_JSON],\"strict_required_status_checks_policy\":true}}"
fi

RULESET_BODY=$(cat <<EOF
{
  "name": "$RULESET_NAME",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/heads/epic/*"], "exclude": [] } },
  "rules": [
    { "type": "pull_request",
      "parameters": {
        "required_approving_review_count": $MIN_APPROVALS,
        "require_code_owner_review": true,
        "dismiss_stale_reviews_on_push": true,
        "required_review_thread_resolution": false,
        "require_last_push_approval": false
      }
    },
    { "type": "non_fast_forward" },
    { "type": "deletion" }$STATUS_RULE
  ]
}
EOF
)

# Lookup is best-effort; discard non-numeric output (e.g. 404 JSON) so a
# missing repo doesn't poison the ID.
EXISTING_ID=$(gh api "repos/$OWNER/$REPO/rulesets" -q ".[] | select(.name == \"$RULESET_NAME\") | .id" 2>/dev/null || true)
[[ "$EXISTING_ID" =~ ^[0-9]+$ ]] || EXISTING_ID=""

if [ -n "$EXISTING_ID" ]; then
  RS_METHOD="PUT";  RS_URL="repos/$OWNER/$REPO/rulesets/$EXISTING_ID"
  echo "   ruleset id=$EXISTING_ID exists; updating"
else
  RS_METHOD="POST"; RS_URL="repos/$OWNER/$REPO/rulesets"
  echo "   ruleset not found; creating"
fi
if [ "$DRY_RUN" = "1" ]; then
  echo "[DRY_RUN] gh api -X $RS_METHOD $RS_URL --input - <<< <ruleset JSON>"
else
  echo "$RULESET_BODY" | gh api -X "$RS_METHOD" "$RS_URL" --input - >/dev/null
fi
echo "   epic/*: ruleset applied"

cat <<MSG

Branch protection installed on $OWNER/$REPO.
Verify in the GitHub UI:
  https://github.com/$OWNER/$REPO/settings/branches   (main protection)
  https://github.com/$OWNER/$REPO/rules               (epic/* ruleset)

Reminder: CODEOWNERS must already be committed to the rig for require_code_owner_reviews=true to actually gate merges.
MSG
