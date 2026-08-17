# Daily factory introspection

Once a day, sweep the factory itself and either mint structural-fix work or surface one operator-visible digest. On a healthy factory, do neither and stay silent.

You are running this because the `daily-introspect` order's check exited 0 and the runtime dispatched this workflow to your pool. The check owns two things at once: the `DAILY_INTROSPECT` environment gate, and the cadence. Nothing nudged you and nothing asked you to decide whether to run — arriving here *is* the decision, already made by the check.

That matters for one reason worth stating plainly. An order that sends an agent a sentence saying "please run the audit" only produces a pass when some agent reads the sentence and chooses to act on it, and the order's clock resets whether or not that happened. This order dispatches the workflow directly, so the trigger and the pass are the same event.

### What this mode is not

The pass looks for shapes that justify a *fix* or an *operator decision*. It is not a status report, and it is not a liveness check. If your factory already runs a morning diagnostic digest, that answers "is everything up"; this answers "is anything structurally wrong, and is it worth changing the factory over".

### One pass per dispatch

A single dispatch runs at most one audit pass. Do not loop inside it. When the audit completes or one of the bounds in the stop-conditions step fires, finish the pass and exit; the next window opens on its own once the interval has elapsed since *this* pass completed.
