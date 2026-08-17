# State across passes

Keep one singleton bead as the pass's memory. Reuse the existing one if there is one; create it the first time with `bd create --type=task --title="daily introspection (state)"`. The title is a contract rather than a label, because the order's cadence check finds this bead by exactly that string.

Record on it:

- `last_pass_at` — the UTC timestamp of the pass you just completed, as `YYYY-MM-DDTHH:MM:SSZ`. Write it at the *end* of the pass, not the start. This is the field the cadence check reads to decide when the next window opens, so a pass that stamps it early moves the next window earlier than the interval you configured.
- `last_pass_findings` — a short summary of what this pass found, so tomorrow's pass can tell a fresh finding from one it already surfaced and avoid minting the same fix twice.
- `last_bd_stats_snapshot` — the `bd stats` output this pass read, for tomorrow's delta comparison. If your factory has a chat-transport helper, stash its status output here too under a key of your choosing.

Keep the keys to the pass itself. If you later add another scheduled capability, give it its own state bead rather than another key on this one: a single record shared by two schedules is how you end up with a field that one of them reads and nothing writes.

The bead is metadata rather than work, so it stays open across passes. Close it only if you are turning the pass off permanently, and even then leaving it open costs nothing and makes re-enabling free.
