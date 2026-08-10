# Coordination channels

How work moves between agents in this factory, and where to look when it stops moving.

## Channel inventory

One row per channel this factory actually uses. Delete the ones you do not, and add the ones you built yourself.

| Channel | Primitive | Persists a restart | Timing | Addressed to | Owner |
| --- | --- | --- | --- | --- | --- |
| Tasks | `bd`, `gc sling` | yes | next eligible pull | a pool | |
| Mail | `gc mail send` | yes | recipient's next turn | one alias, or `--all` | |
| Orders | `gc order` | yes (definition on disk) | schedule or predicate | a pool, or the controller | |
| Nudges | `gc session nudge` | no | immediate, if the session is alive | one session | |
| Session attach | `gc session attach` | no | immediate | one session | |

Fill in the owner column. A channel with no owner is one nobody notices has broken.

## Preferences by handoff

One row per handoff in your pipeline. The primary is what carries it normally; the fallback is what you reach for when the primary has clearly not fired.

| Handoff | Primary | Fallback | Why |
| --- | --- | --- | --- |
| Human → front gate | | | |
| Front gate → implementer | | | |
| Implementer → reviewer | | | |
| Reviewer → implementer (bounce) | | | |
| Reviewer → architecture review | | | |
| Architecture review → reviewer | | | |
| Reviewer → human (merge) | | | |
| Any agent → human (blocked) | | | |
| Nothing → factory (scheduled sweeps) | | | |

## Protocols

Anything an agent has to do beyond picking the right channel. Two examples to replace with your own:

- **Blocked work always mails a human, never only sets a status.** A blocked bead is invisible unless somebody is looking at the board; a mail is not.
- **A nudge is never the only signal.** If a nudge is the mechanism, something durable carries the same intent, because a nudge to a dead session is gone with no trace.

## When the factory goes quiet

The diagnostic order that follows from the table above. Adjust it to match your own primaries.

1. `bd list --status open` — is there work, and does it have an assignee?
2. `gc session list` — is anything alive that could pick it up?
3. `gc mail inbox <alias>` — is a message sitting unread?
4. `gc order check` — should something have fired, and did it?
5. `gc session peek <id>` — is an agent alive but stuck mid-turn?
