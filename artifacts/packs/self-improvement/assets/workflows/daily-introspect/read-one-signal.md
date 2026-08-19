# Read one signal the factory already writes

You're here because the `daily-introspect` order's check exited 0 and the runtime dispatched this workflow to you. Nothing nudged you. Nothing asked whether today's a good day for it either, because arriving here is that decision, already made.

Your factory writes signals all day without being asked to, and this step reads one of them. Start with blocked beads. A blocker carries a reason, and reasons repeat.

```bash
bd list --status blocked --limit 0 --json | jq -r '.[] | "\(.id)\t\(.metadata.blocker_reason // "no reason recorded")\t\(.title)"'
```

Group what comes back by the reason rather than by the bead. One blocked bead is a bad afternoon. The same reason on two or more is a shape, and that's the thing worth acting on, because something in the factory should have stopped the second one from happening.

What you're after is a change to the factory rather than a change to the work. A prompt that never said the thing, a script with no guard on it, an order whose gate reads the wrong variable: those are findings. A bead that's genuinely waiting on a person isn't.

One signal is enough for one pass. When you've got your list, go to the next step. If nothing's blocked at all you still have a result, and the next step says what to do with it.
