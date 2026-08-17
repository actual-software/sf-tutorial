# The bounded audit pass

Both bounds apply, and whichever fires first stops the pass:

- **Time:** roughly 5 minutes of agent time, maximum. If the checklist is unfinished at 5 minutes, stop, surface whatever findings you already have, and exit. Do not extend the pass.
- **New work items:** at most **3 structural-fix beads minted per pass**. If you would mint a fourth, summarize the remainder in the digest (or via `bd human`) instead. The cap is deliberately tight, because a structural-fix bead asks the next builder to ship a factory-wide change and three of those is already a real load on the build queue.

Walk this checklist top to bottom until one of the bounds fires.

- **Queue health.** Beads stuck `in_progress` for more than 4 hours, which usually means a worker crashed mid-flow without exiting. Parked beads whose park reason has aged out, so the condition they were waiting on is no longer true. Never-dispatched high-priority beads. Beads whose assignee names a session that no longer appears in `gc session list`.
- **Blocker patterns.** Group the last 24 hours of blocked beads by their blocker reason. One blocker is noise. The same shape across two or more beads is a structural-fix candidate, because a prompt or a helper script should have prevented the second one.
- **Pool-dispatch hygiene.** Beads where the routing metadata and the live `assignee` field disagree across agent classes, and any pool-alias conflicts in the controller logs. These are silent misroutes: no session spawns, and the work sits there looking merely slow.
- **Store and transport health.** A `bd stats` snapshot compared against the previous day's, which the state step stashes for exactly this. Surface the deltas rather than the absolute numbers: mail queue depth growth, connection failures, a restart count that climbed overnight. If your factory has a chat-transport helper, add its status output to the same comparison; if it does not, this bullet is `bd stats` alone and still worth walking.
- **Prompt drift against recent incidents.** Scan the last 20 or so closed beads for verdict summaries shaped like "the prompt should have said X" or "this would not have happened if Y were in the contract". One is a note to self. A pattern is a prompt change.
- **Insight-capture rate.** If your team keeps a shared knowledge base in a repo, ask whether anything landed in it in the last 24 hours. A day in which builders shipped real work and nobody wrote anything down is a signal that the lessons are evaporating. The probe below needs your own repo, so it ships commented out rather than pointing somewhere that will not resolve for you:

  ```bash
  # gh search commits --repo <your-org>/<your-knowledge-repo> --author-date=">=$(date -u -d '1 day ago' '+%Y-%m-%d')"
  ```

The list is a starting set rather than a closed one. If a pass turns up a recurring shape that fits none of these categories, surface it in the digest and ask whether the checklist itself should grow. A gap in the checklist is a structural-fix candidate in its own right.
