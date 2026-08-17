# Daily factory introspection

Once a day, sweep the factory itself and either mint structural-fix work or surface one operator-visible digest. On a healthy factory, do neither and stay silent.

You're running this because the `daily-introspect` order's check exited 0 and the runtime dispatched this workflow to your pool. The check owns two things at once: the `DAILY_INTROSPECT` environment gate, and the cadence. Nothing nudged you, and nothing asked you to decide whether today is a good day for it. Arriving here *is* the decision, already made by the check.

That's worth stating plainly, because the alternative is so easy to write by accident. An order that sends an agent a sentence saying "please run the audit" only produces a pass if some agent reads the sentence and chooses to act on it, and the order's clock resets either way. This one dispatches the workflow directly, so the trigger and the pass are the same event.

### What the pass is looking for

Shapes that justify a *fix* or an *operator decision*. It isn't a status report and it isn't a liveness check, so if your factory already runs a morning diagnostic digest, that one answers "is everything up" and this one answers "is anything structurally wrong, and is it worth changing the factory over".

### One pass per dispatch

A single dispatch runs at most one audit pass, so don't loop inside it. When the audit completes, or one of the bounds in the stop-conditions step fires, finish the pass and exit. The next window opens on its own once the interval has elapsed since *this* pass completed.
