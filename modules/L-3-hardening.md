# L-3 · Work on Your Factory: Hardening

« [previous: L-2 Retargeting the Rig](./L-2-retargeting-the-rig.md) | [next: L-4 Self-improvement Loop](./L-4-self-improvement-loop.md) »

**Lab · Thursday 10:45–12:00 · 75 minutes · your own project**

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [Choose one: scoring or multi-vendor](#choose-one-scoring-or-multi-vendor)
- [How the lab runs](#how-the-lab-runs)
- [Track A · Per-principle scoring with an audit trail](#track-a--per-principle-scoring-with-an-audit-trail)
- [Track B · Multi-vendor review with a synthesizer](#track-b--multi-vendor-review-with-a-synthesizer)
- [Deliverable](#deliverable)
- [Verification](#verification)
- [If you fall behind](#if-you-fall-behind)
- [Ceiling](#ceiling)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

Take one review mechanism past "an agent looked at it" and into something you could show an auditor or a skeptical colleague. You pick which of two directions that means.

## Prereqs

- [L-2](./L-2-retargeting-the-rig.md) complete, or `ascii-art` at the end of W-5 if you are running this on the shared example.
- For Track B only: `codex`, `claude` and `gemini` all installed and authenticated on your machine. Check this *before* the block starts, not at 11:00.

## Choose one: scoring or multi-vendor

This is the longest lab of the two days and it is the meatiest choice. The two tracks solve different problems and you have time for one.

| | Track A · Scoring | Track B · Multi-vendor |
| --- | --- | --- |
| Source page | [`hardening/03`](../hardening/03-architecture-best-practices-loop.md) | [`hardening/04`](../hardening/04-strengthen-review-system.md) |
| The problem it solves | "The reviewer said it was fine" is not evidence | One model's blind spot is the whole factory's blind spot |
| What you build | Per-principle scores against a 23-principle schema, with an append-only YAML audit trail per iteration | Three vendor-pinned reviewers in parallel, fused by a synthesizer with a majority rule |
| Pick it if | You need to defend a decision later, or your organisation will ask "on what basis" | You have seen a model be confidently wrong, or you want a cheaper model doing the first pass |
| Extra setup | None beyond the pack | Three CLI providers installed and authenticated |
| Watch out for | The schema is the work. A vague principle scores meaninglessly. | Cost and latency both roughly triple |

Track B also answers a question that comes up in almost every factory conversation: whether a cheaper model can carry part of the review load. Running three vendors side by side on the same bead is the fastest way to find out on your own code, rather than on a benchmark.

If you genuinely cannot choose, take Track A. The audit trail is useful to more people more often, and Track B is the easier of the two to work through alone afterwards.

## How the lab runs

Twenty-five minutes of demo covering both tracks, then fifty minutes in which you build one. Say which track you picked when the instructor comes round, so pairing lands sensibly.

## Track A · Per-principle scoring with an audit trail

Work [`hardening/03-architecture-best-practices-loop.md`](../hardening/03-architecture-best-practices-loop.md).

Its shape: install the `principles-loop-rig` pack, author and commit a principles schema, run a clean bead through the loop and watch it pass on iteration 1, then run a deliberately weak bead and watch the loop iterate.

The part that transfers to your project is step 2, authoring the schema. `ascii-art`'s schema has 23 principles because its domain is small and closed. Yours will not be. Write five principles you would actually defend in a design review rather than twenty-three you copied, and make each one specific enough that two reviewers would score it the same way. "Code should be maintainable" scores randomly. "Every public function that can fail returns an error rather than raising" scores consistently.

The audit trail is append-only YAML, one entry per iteration. Open it after your second run. It is the artifact that answers "on what basis", and it is the reason this track is worth 50 minutes.

## Track B · Multi-vendor review with a synthesizer

Work [`hardening/04-strengthen-review-system.md`](../hardening/04-strengthen-review-system.md).

Its shape: install the `multi-vendor-rig` pack, verify three CLI providers are authenticated, carry a clean bead through the standard pipeline, then review it with three vendor-pinned reviewers in parallel and fuse the results with a synthesizer. Then repeat with a deliberately weak bead to exercise disagreement, the majority rule, and the refinery's bounce path.

Step 6 is the one that matters. Vendor agreement on a clean bead tells you very little; the interesting signal is where they disagree and what the synthesizer does about it. Read the three raw verdicts before you read the synthesized one, and decide for yourself which reviewer was right. If the majority was wrong, that is a finding about your synthesizer's rule rather than about the models.

Check your provider auth first. `hardening/04` step 1 verifies all three, and an unauthenticated provider fails late and confusingly.

## Deliverable

Either an append-only audit trail with per-principle scores for at least two runs, or three vendor verdicts on one bead plus the synthesizer's fused result and a note on where they disagreed.

Both tracks produce a file you can show someone. That is the point of the block.

## Verification

Track A:

```bash
ls -la <your-rig>/docs/reviews/
tail -40 <your-rig>/docs/reviews/*.yaml
```

Track B:

```bash
gc session list
bd show <bead-id> --json | jq '.[0].metadata | to_entries | map(select(.key | startswith("vendor")))'
```

## If you fall behind

Both tracks run fine on `ascii-art` if your own rig is not cooperating:

```bash
cd path/to/sf-tutorial/bootstrap
./bootstrap.sh 05.1-bead-gate-checks
```

Then work your chosen hardening page as written. Retarget afterwards; the mechanics are identical and the setup cost is what you are avoiding.

## Ceiling

Run the other track. That is genuinely the best use of extra time here, and the two compose: per-principle scoring gives the multi-vendor synthesizer something concrete to disagree about, instead of three prose opinions it has to reconcile by vibe.

If you would rather go deeper than wider, take the track you chose and make it fail on purpose. Write a principle no reviewer can score, or pin two of the three vendors to the same model and see whether your majority rule notices. A gate you have not seen fail is a gate you do not yet understand.

## Troubleshooting

- **The scoring loop never converges.** At least one principle is unscoreable as written. Read the lowest-scoring entry in the audit trail; the reviewer's own comment usually names the ambiguity.
- **One vendor lane hangs.** That provider is not authenticated, or its CLI is not on `PATH` for the agent's environment. Run its `--version` command yourself in a fresh shell.
- **The synthesizer picks an answer you disagree with.** That is a real result, not a bug. Its rule is in `artifacts/packs/multi-vendor-rig/agents/synthesizer/prompt.template.md`, and editing it is a legitimate use of the remaining time.

## What's next

You have made the factory's reviews stronger. [L-4 Self-improvement Loop](./L-4-self-improvement-loop.md) points the factory at its own configuration.

« [previous: L-2 Retargeting the Rig](./L-2-retargeting-the-rig.md) | [next: L-4 Self-improvement Loop](./L-4-self-improvement-loop.md) »
