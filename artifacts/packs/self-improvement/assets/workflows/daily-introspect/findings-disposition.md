# What to do with findings

Every finding gets exactly one of three dispositions. Pick the smallest one that fits.

**Structural-fix candidate.** A change to a prompt, a helper script, an order's gate, a pack config — something a builder can ship. Mint it as a bead whose deliverable names the path the change lands under, using the `SELF_IMPROVEMENT_DELIVERABLE_ROOT` value from your `.env` (the repo or directory holding your factory's configuration), and dispatch it the way your factory dispatches any other build. The description should cite the audit signal you actually saw, with counts: "the same blocker reason appeared on four beads in 24 hours, up from zero" or "two beads this week hit the same misroute shape". The next builder needs to be able to check your diagnosis before shipping against it. Subject to the three-per-pass cap.

**Operator-decision item.** Something that needs a person to choose between two reasonable directions, authorize something irreversible, or weigh a policy question: deprioritize an agent, accept a known-failing check, change a quota. File it with `bd human` so your operator-facing loop picks it up, and include it as a bullet in the digest. Do not quietly mint a structural-fix bead instead. An operator-decision item is precisely the case where any "fix" presupposes an answer nobody has given yet, and minting one is how a factory talks itself into a decision its operator never made.

**Routine still-healthy outcome.** Nothing is structurally wrong and nothing needs a person. Stay silent.

That third disposition is the one that takes discipline. The pass is not a notification, so an empty digest is worse than no digest: post one every day and you train your operator to skip the channel on the day a real finding lands in it.
