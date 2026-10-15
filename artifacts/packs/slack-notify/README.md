# slack-notify

An optional Day 2 pack. Each time the factory closes a piece of work on your rig, a message lands in a Slack channel, with the pull request link when the work went through the PR path. The lab that walks through it is [Slack notifications](../../../hardening/08-slack-notifications.md).

It's one-way. The factory posts to Slack, Slack never talks back, and the whole pack is one order, one script and an incoming webhook. Nothing in it runs a model.

## Example posts

One closed bead with a PR:

```text
✅ Closed on ascii-art: `aa-0fd` Implement d.md · PR #3
```

`PR #3` is a link to the pull request. More than five closes in one firing arrive as a single summary instead, listing up to twenty of them:

```text
✅ ascii-art closed 6 beads:
• `aa-6ao` Implement e.md
• `aa-pps` Implement f.md · PR #4
• ...
```

## Relation to base-factory

`bead-closed-slack` is [base-factory](../base-factory/README.md)'s `bead-closed-log` with a channel in place of a file: same `event` trigger on `bead.closed`, same exec that asks `bd` what is closed and skips what it has already handled. Read the two order files side by side.

The difference is in what the script owes once the output reaches people. A duplicate log line costs nothing, and a duplicate post is noise in a channel your team reads. So `assets/scripts/bead_closed_slack.sh` adds four things on top of the log script:

| | Behaviour | Reason |
|---|---|---|
| Filter | Posts tasks, bugs, features, chores and epics, and skips any bead a formula created | A sling through `mol-polecat-pr` closes a step bead at each stage. Without the filter, one sling would post a dozen times. |
| Baseline | The first run records every bead already closed and posts none of them | Installing on a factory that has run all day would otherwise replay its history into the channel. |
| Burst cap | More than five new closes in one firing become one summary message | A burst of closes costs one webhook call. |
| Secret | The URL is read from `.env`, passed to `curl` on stdin, and never printed | Anyone holding the URL can post to your channel. |

```mermaid
flowchart LR
    C["A bead closes"] --> E["bead.closed event"]
    E --> O["bead-closed-slack<br/>order fires"]
    O --> S{"script"}
    S -->|"first run"| B["Record what is<br/>already closed"]
    S -->|"new work items"| P["Post one message each,<br/>or one summary"]
    P -->|"Slack answers 200"| R["Add the ids<br/>to the sent list"]
    P -->|"Slack fails"| N["Leave them unsent;<br/>the next firing retries"]
```

## Adding it to your base factory

You need a factory from [W3](../../../progression/W3-run-your-factory.md) and an incoming webhook URL. The lab page walks through creating the Slack app from [`assets/slack-app-manifest.json`](assets/slack-app-manifest.json), which asks for the `incoming-webhook` scope and nothing else: no other scopes, no Socket Mode, no event subscriptions.

The URL goes in the city's `.env`, and `.env` goes in the city's `.gitignore`, which `gc init` writes without it:

```bash
cd "$SFI_PATH/factory1"
grep -qxF .env .gitignore || echo .env >> .gitignore
printf 'Paste the webhook URL, then press Enter: '; read -r URL
echo "SLACK_WEBHOOK_URL=$URL" >> .env; unset URL
```

Then install the pack on the rig and fire it once, which records the baseline:

```bash
gc import add --rig ascii-art "$SFI_PATH/sf-tutorial/artifacts/packs/slack-notify"
gc reload
gc order run bead-closed-slack
```

Rig scope, like base-factory's orders, so it posts the rig's work and none of the city's own housekeeping. Import it on a second rig and that rig gets its own sent list; from then on, name the rig when you fire it by hand, as in `gc order run bead-closed-slack --rig ascii-art`.

## Settings

| Location | Setting | Default | Effect |
|---|---|---|---|
| `$SFI_PATH/factory1/.env` | `SLACK_WEBHOOK_URL` | unset | The incoming webhook to post to. Unset means installed but switched off: the order fires and the script exits without doing anything. |
| `assets/scripts/bead_closed_slack.sh` | `BURST_MAX` | `5` | More new closes than this in one firing post as one summary. |
| `assets/scripts/bead_closed_slack.sh` | `SUMMARY_LINES` | `20` | Beads a summary lists before it says how many more there are. |
| `assets/scripts/bead_closed_slack.sh` | `WORK_TYPES` | task, bug, feature, chore, epic | The bead types that post. |

The script reads `.env` itself because an exec order never loads it. The [self-improvement pack](../self-improvement/README.md) does the same for its switch.

The other three live in the script. Here's the catch: an import from inside a git repository is pinned to the commit it was added at, so editing `sf-tutorial` in place won't change what the order runs. To tune them, copy the pack somewhere outside git, edit the copy, and import that path instead, since an import from outside git reads the files as they are.

## State

The sent list lives at `.gc/runtime/packs/slack-notify/<rig>/sent` under the city. It's plain text, one bead id per line, holding everything already posted plus everything that was already closed at install. Because it sits under `.gc/`, it never gets near the rig's git history. Want a fresh baseline? Delete the file, and the next firing records what's closed and posts none of it.

A failed post leaves its beads off the list, so the next firing tries them again. When the controller's firing fails, `gc events --type order.failed` shows the script's message, usually the HTTP status Slack answered with.

## Turning it off

Either take the URL out or take the pack out:

```bash
cd "$SFI_PATH/factory1"
grep -v '^SLACK_WEBHOOK_URL=' .env > .env.new; mv .env.new .env      # keep the pack, stop posting
gc import remove --rig ascii-art slack-notify && gc reload          # take the pack back out
```

With the URL gone, beads keep closing and nothing is recorded. Put the URL back and the next firing posts what closed in the meantime, as one summary when there are more than five.
