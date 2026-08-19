# Stamp the pass and stop

Keep one bead as the pass's memory. Reuse the existing one; create it the first time with:

```bash
bd create --type=task --title="daily introspection (state)"
```

That title is a contract rather than a label, because the order's check finds this bead by exactly that string. Change it in one place and you have to change it in the other.

Record the finish time on it, in UTC:

```bash
bd update <state-bead-id> --set-metadata last_pass_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
```

Write it at the end of the pass rather than at the start. The check reads this field to decide when the next window opens, so a pass that stamps itself early moves tomorrow's window earlier than the cadence you configured.

Then stop. One dispatch is one pass, so do not loop looking for more. The next window opens on its own once the interval has elapsed since this pass finished.
