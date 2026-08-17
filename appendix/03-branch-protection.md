# Branch Protection

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context](#context)
- [Setup](#setup)
  - [Bootstrap Factory1 with Script](#bootstrap-factory1-with-script)
  - [Build Factory1 by Hand](#build-factory1-by-hand)
    - [1. Copy CODEOWNERS into the rig](#1-copy-codeowners-into-the-rig)
    - [2. Inspect the protection script](#2-inspect-the-protection-script)
    - [3. Dry-run the script](#3-dry-run-the-script)
    - [4. Apply the protection](#4-apply-the-protection)
- [Try It](#try-it)
  - [1. Prove the gate is on (without review)](#1-prove-the-gate-is-on-without-review)
  - [2. Approve and merge](#2-approve-and-merge)
  - [3. Watch a direct push get rejected](#3-watch-a-direct-push-get-rejected)
  - [4. Reflect](#4-reflect)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

By the end of this exercise you will have branch protection on `main` and a ruleset on `epic/*` that blocks merges until a CODEOWNER approves the PR.

## Prereqs

- Page 02 complete: the `factory1` pack is installed, `mol-polecat-pr`
  and `mol-refinery-pr-patrol` are in use, and PRs are publishing for slung beads.
- `gh auth status` succeeds and your account has **admin** permission on the
  rig's GitHub repo. Without admin, the protection API returns 403.
- `jq` is installed (used by the verification commands below).

## Context

Page 02's reflection named the gap: "the gate is open. Anyone can merge
that PR with no required reviewers and no required CI." This page fixes
the **reviewers** half. Branch protection turns merging into a gated
action — GitHub refuses the merge until a CODEOWNER has approved. The
gate lives in the repo's settings; no formula or agent change required.

The required-CI half needs an actual workflow producing a check, so it
is forward-referenced to **Hardening 1** and intentionally left out of
this page.

## Setup

This lesson has two paths to the same end state. Pick one.

### Bootstrap Factory1 with Script

If this is your first run, complete the one-time setup in the [bootstrap README](../bootstrap/README.md) (`.env`, `deps.sh`) before invoking the script.

**Copy and paste**

```bash
cd path/to/sf-tutorial/bootstrap
./bootstrap.sh 03-branch-protection
```

The script reproduces every step up through this lesson — `.github/CODEOWNERS` is copied in, committed, and pushed to `main`, and `branch-protection.sh` runs against the rig's GitHub repo to install the `main` protection rule and the `epic/*` ruleset.

After it finishes, re-export the four env vars per [W3 Run Your Factory](../progression/W3-run-your-factory.md), then jump to [Try It](#try-it).

### Build Factory1 by Hand

### 1. Copy CODEOWNERS into the rig

Branch protection's `require_code_owner_reviews=true` only enforces against
people listed in `CODEOWNERS`. The file must live on `main` for GitHub to
recognize it — if it's only on a feature branch, the gate has nothing to
match against.

**Copy and paste**

```bash
cd $ASCII_ART_PATH
mkdir -p .github
cp $ARTIFACTS_PATH/github/CODEOWNERS \
  .github/CODEOWNERS
```

Replace the string `@your-github-handle` with your actual GitHub handle
(or a team like `@your-org/reviewers`). Then commit and push to `main`:

**Copy and paste**

```bash
export GITHUB_USERNAME=$(gh api user -q '.login')

sed "s/@your-github-handle/@$GITHUB_USERNAME/g" .github/CODEOWNERS > .github/CODEOWNERS.tmp \
  && mv .github/CODEOWNERS.tmp .github/CODEOWNERS

git add .github/CODEOWNERS
git commit -m "chore: add CODEOWNERS"
git push origin main
```

Three details in that `sed` matter, and getting any of them wrong produces a `CODEOWNERS` that GitHub accepts as a file but ignores as a rule:

- **Double quotes, not single.** Single quotes stop `$GITHUB_USERNAME` expanding, and the file ends up containing the literal string `$GITHUB_USERNAME`.
- **Keep the leading `@`.** An owner without it is not a valid `CODEOWNERS` entry, so the line silently matches nobody.
- **Write to a temp file and move it back** rather than editing in place. GNU `sed` (Linux) and BSD `sed` (macOS) disagree about the argument `-i` takes, so no single `sed -i` spelling works on both. Redirecting and moving works everywhere.

Confirm the file on GitHub actually names *your* handle — not just that a file exists there:

**Copy and paste**

```bash
gh api "repos/$GITHUB_USERNAME/ascii-art/contents/.github/CODEOWNERS" \
  -H "Accept: application/vnd.github.raw" | grep "^\*[[:space:]]*@$GITHUB_USERNAME$"
```

**Expected output** — with your own handle in place of `@your-actual-handle`:

```text
*       @your-actual-handle
```

That `grep` matches only a default-owner line that names *your* handle with its leading `@`, so **no output at all means the substitution didn't take** — the file still says `@your-github-handle`, or says `$GITHUB_USERNAME` literally, or has lost the `@`. Fix it, commit, and push again before moving on — GitHub will happily store a `CODEOWNERS` whose owner matches nobody, and branch protection will then block every merge with no reviewer who can approve it.

### 2. Inspect the protection script

Read the script before running it.

**Copy and paste**

```bash
cat $ARTIFACTS_PATH/github/branch-protection.sh
```

What to notice:

- **Two operations.** A `PUT` to `repos/<owner>/<repo>/branches/main/protection`
  installs single-branch protection on `main`. A `POST` (or `PUT`-update if
  one with the same name exists) to `repos/<owner>/<repo>/rulesets`
  installs a ruleset matching `epic/*` branches.
- **Env-var contract.** `OWNER` and `REPO` are required (exit 2 if missing).
  `MIN_APPROVALS` defaults to `1`. `STATUS_CHECKS` defaults to empty — no
  required CI yet, by design.
- **`enforce_admins=true`.** This is the line that makes the gate real.
  GitHub's classic branch protection treats admins as exempt by default;
  with `enforce_admins=false`, a `git push origin main` from the repo
  owner succeeds and the API just records "Bypassed rule violations" in
  the response. Since the rig owner (you) is a repo admin, leaving this
  off would silently let the polecat — or any other tool running with
  your token — short-circuit the entire PR gate. The script forces it
  on so admins are bound by the same rule as everyone else.
- **Idempotency key.** The ruleset's `name`
  (`"Epic branches require human review"`) is the lookup the script uses to
  decide between create and update. Don't rename it or you'll get duplicates.
- **Exit codes.** `2` = missing env, `3` = `gh` missing or unauthed,
  `4` = no admin. These map to the Troubleshooting bullets below.

### 3. Dry-run the script

A dry run prints what would happen without making any API calls. Sanity-check
`OWNER` and `REPO` before changing real settings.

**Copy and paste**

```bash
export OWNER=$GITHUB_USERNAME
export REPO=ascii-art
DRY_RUN=1 $ARTIFACTS_PATH/github/branch-protection.sh
```

You should see two `[DRY_RUN] gh api ...` lines on stderr (one for `main`,
one for the ruleset) plus the closing "Branch protection installed" banner.
No state changes yet.

### 4. Apply the protection

Drop `DRY_RUN`:

**Copy and paste**

```bash
$ARTIFACTS_PATH/github/branch-protection.sh
```

Confirm in the GitHub UI:

- `https://github.com/$OWNER/$REPO/settings/branches` shows a protection rule
  on `main` with "Require a pull request before merging" and "Require
  approvals (1)" both checked, plus "Require review from Code Owners".
- `https://github.com/$OWNER/$REPO/rules` lists a ruleset named
  **Epic branches require human review** targeting `epic/*`.

Or check via API:

**Copy and paste**

```bash
gh api "repos/$OWNER/$REPO/branches/main/protection" \
  | jq '{required_pull_request_reviews, enforce_admins: .enforce_admins.enabled}'
```

You should see `required_approving_review_count: 1`,
`require_code_owner_reviews: true`, and `enforce_admins: true`.
The last one is what stops repo admins (you) from `git push`-ing
straight to `main`.

## Try It

### 1. Prove the gate is on (without review)

Sling the next letter — `f.md`:

**Copy and paste**

```bash
export BEAD_ID=$(bd list --type=task --status=open --limit 0 | grep -E "Implement f.md$" | awk '{print $2}')
bd show $BEAD_ID

cd $FACTORY_PATH
gc sling ascii-art/review-loop-rig.polecat $BEAD_ID --on mol-polecat-pr
```

Watch the bead go through the status changes, and attach to the
polecat and refinery sessions to see the PR being published. Then,
when `pr_number` is set, attempt to merge **without a review**:

**Copy and paste**

```bash
cd $ASCII_ART_PATH
export PR=$(BD_JSON_ENVELOPE=1 gc bd show $BEAD_ID --json | jq -r '.data[0].metadata.pr_number')
gh pr merge "$PR" --merge
```

**Expected output**

```text
X Pull request <your-github-username>/ascii-art#N is not mergeable: the base branch policy prohibits the merge.
```

You may also see `At least 1 approving review is required by reviewers
with write access` or `Required review from a code owner has not been
provided`. Any of those mean the gate is doing its job. Leave the PR
open — the next step approves it.

### 2. Approve and merge

Open the PR for review:

**Copy and paste**

```bash
gh pr view "$PR" --web
```

You must be a CODEOWNER **other than the PR author** for the approval to count — GitHub refuses to let a PR's author approve their own PR, and the polecat opened this PR using your token. Have a teammate listed in `CODEOWNERS` approve it, then run `gh pr merge "$PR" --merge`.

If you're working solo and your only CODEOWNER is you, none of the merge surfaces will work — `enforce_admins=true` (set in step 4) binds you to the same rule as everyone else, so the UI's override checkbox won't appear either. See the [`can't approve own PR`](#troubleshooting) troubleshooting bullet for the three documented escape hatches (second CODEOWNER, separate bot identity, or temporary `MIN_APPROVALS=0`).

Confirm the merge landed on `main`:

**Copy and paste**

```bash
git fetch origin && git pull
git log --oneline origin/main -1
ls ascii/ | grep -i 'f'
```

You should see a new merge (or squash) commit on `origin/main` and the
`f`-letter file present in `ascii/`.

### 3. Watch a direct push get rejected

The PR path works because branch protection allows it. To see what protection actually blocks, try the obvious shortcut — commit a change to `main` locally and push it.

First, pin the current `main` commit so you can restore it afterward.

**Copy and paste**

```bash
cd "$ASCII_ART_PATH"
git checkout main
git fetch origin && git pull
export CURRENT_COMMIT=$(git rev-parse HEAD)
echo "Pinned main at $CURRENT_COMMIT"
```

Make a trivial change directly on `main` and commit it.

**Copy and paste**

```bash
echo "bypass attempt $(date +%s)" >> README.md
git add README.md
git commit -m "chore: try to bypass branch protection"
```

Now push.

**Copy and paste**

```bash
git push origin main
```

**Expected output**

```text
remote: error: GH006: Protected branch update failed for refs/heads/main.
remote: error: At least 1 approving review is required by reviewers with write access.
 ! [remote rejected] main -> main (protected branch hook declined)
error: failed to push some refs to '…/ascii-art.git'
```

GitHub refuses the push. `enforce_admins=true` binds you to the same rule a non-admin would hit. The polecat — running under your token — would get the same rejection if it tried to fast-forward `main` directly, which is why `mol-polecat-pr` opens a PR instead.

Reset `main` back to where it was and discard the local bypass commit.

**Copy and paste**

```bash
git reset --hard $CURRENT_COMMIT
git log --oneline -1
```

**Expected output**

```text
HEAD is at <CURRENT_COMMIT short> <subject of the last legitimate merge commit>
```

Your local `main` once again matches `origin/main`. Nothing landed on the remote.

### 4. Reflect

**What changed.** A human — or another agent acting as a CODEOWNER — must
approve every PR before it can merge to `main`. Direct merges are gone,
including for repo admins: `enforce_admins=true` binds the rig owner to
the same rule. The polecat publishes a PR, but the PR cannot land until
a real review sits on it. The gate is no longer just a surface; it is a
guard.

**What's still missing.** Two things. First, there is no automated check
for ADR adherence — a human has to remember to compare every diff against
`0001.ADR.ASCII.md`, and humans forget. **Page 04 — ADR reviewer** adds
an AI reviewer that runs `gh pr review` automatically against that ADR,
so every PR receives a structured ADR check before the human looks.
Second, no CI status check is required. A reviewer could approve a PR
with broken tests and the merge would still go through. **Hardening 1 —
Required CI** wires a workflow into branch protection so failing tests
block the merge regardless of approvals.

## Verification

- `gh api "repos/$OWNER/$REPO/branches/main/protection" | jq '.required_pull_request_reviews.required_approving_review_count'`
  returns `1`.
- `gh api "repos/$OWNER/$REPO/branches/main/protection" | jq '.required_pull_request_reviews.require_code_owner_reviews'`
  returns `true`.
- `gh api "repos/$OWNER/$REPO/branches/main/protection" | jq '.enforce_admins.enabled'`
  returns `true`. Without this, repo admins (the rig owner) can
  `git push origin main` directly and bypass the PR gate; GitHub
  records "Bypassed rule violations" but accepts the push.
- A direct push to `main` from an admin-token clone fails:

  **Example**

  ```bash
  git push origin <some-sha>:main
  # ! [remote rejected] <sha> -> main (protected branch hook declined)
  ```
- The `epic/*` ruleset exists:

  **Copy and paste**

  ```bash
  gh api "repos/$OWNER/$REPO/rulesets" \
    | jq '.[] | select(.name=="Epic branches require human review") | {id, target, enforcement}'
  ```
  returns one object with `target: "branch"` and `enforcement: "active"`.
- `gh pr merge "$PR" --merge` against an unreviewed PR fails with a clear
  "review required" / "base branch policy prohibits the merge" error.
- After `gh pr review "$PR" --approve` from a CODEOWNER, `gh pr merge
  "$PR" --merge` succeeds.
- The merged file (`ascii/f*`) is on `origin/main`.

## Troubleshooting

- **Exit 2.** `OWNER` or `REPO` not exported. Run
  `export OWNER=your-github-org-or-user REPO=ascii-art` and re-run.
- **Exit 3.** `gh` missing or unauthed. Run `gh auth login`, then
  `gh auth status`.
- **Exit 4.** Your account is not admin on the repo. Use a repo you own,
  or ask an admin to grant rights via
  `Settings → Collaborators and teams → Add → Admin`.

- **`gh pr merge` succeeds without a review** (gate not enforcing).
  Three things to check, in order:
  1. CODEOWNERS is on `main` and lists your handle:
     `gh api "repos/$OWNER/$REPO/contents/.github/CODEOWNERS" -q '.path'`
     must echo `.github/CODEOWNERS`.
  2. Code-owner review is required:
     `gh api ".../branches/main/protection" | jq '.required_pull_request_reviews.require_code_owner_reviews'`
     must be `true`.
  3. Admins are bound by the rule:
     `gh api ".../branches/main/protection" | jq '.enforce_admins.enabled'`
     must be `true`. If it's `false`, an older version of the script ran
     (which set it explicitly off). Re-run `branch-protection.sh` to fix
     it, or apply just that one field:
     `gh api -X POST repos/$OWNER/$REPO/branches/main/protection/enforce_admins`.

- **`gh pr review --approve` fails with "can't approve own PR".** GitHub
  refuses to let a PR's author approve it. The polecat published this PR
  as the rig's GitHub identity, which is typically your own account.
  Workarounds, in order of preference: (1) have a second GitHub account
  or teammate added as a CODEOWNER approve the PR; (2) configure the rig
  to use a separate bot account so author and reviewer differ; (3) as a
  last resort for a solo learner, temporarily set `MIN_APPROVALS=0` and
  re-run the script for this one merge, then re-tighten immediately. The
  third option defeats the gate — only use it to unblock the exercise.
  Page 04's AI reviewer does not solve this either; GitHub also refuses
  reviews from the PR-author identity. Plan for a separate approver
  identity before relying on this gate in real work.

- **Ruleset already exists with the same name.** The script handles this
  via the `PUT`-update path. If you see a duplicate in
  `https://github.com/$OWNER/$REPO/rules`, you renamed the ruleset
  between runs. Rename it back to **Epic branches require human review**
  (the script's idempotency key) and delete the duplicate manually.

- **`gh pr merge` fails with "required status check" before any review.**
  You set `STATUS_CHECKS` on a previous run and there's no workflow
  producing that context. Re-run the script with `STATUS_CHECKS=""` (or
  unset it) to clear the requirement until Hardening 1.

## What's next

Continue to [ADR reviewer](./04-adr-reviewer.md).

« [previous: the review-loop appendix](./02-first-review-loop.md) | [next: the architect appendix](./04-adr-reviewer.md) »
