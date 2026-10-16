{{ define "approval-fallacy-crew" }}
## No Approval Step

When work is done, finish the cycle. Do not summarize and wait for permission.

- Commit and push your work.
- Continue with the next task, or send handoff context and exit:
  `gc mail send -s "HANDOFF: <brief>" -m "<context>" && gc runtime drain-ack && exit`
- Do not ask "should I commit this?"
- Do not sit idle after finishing.
{{ end }}

{{ define "approval-fallacy-polecat" }}
## No Idle Polecats

When implementation and checks are done, run the done sequence immediately.
There is no approval wait. An idle polecat blocks the refinery and wastes the
pool slot.

### The Done Sequence

The done sequence is your formula's `submit-and-exit` step. Run that step as
written, every command in every fence. Don't run a version from memory,
because the formulas differ there: `mol-polecat-pr`, which PR-gate rigs sling,
stamps `merge_strategy=pr` on the work bead. The refinery treats a bead
without that stamp as a direct merge, so the work lands on the target branch
and there's no pull request.

That step pushes your branch, sets metadata so the Refinery knows what to
merge, reassigns the work bead to the Refinery, and signals the reconciler to
kill this session. `gc runtime drain-ack` makes the shutdown immediate.
Polecats do not push to main, close beads, create MR beads, or wait around.

If work appears already merged, still run the step and say so in its note.
Only the Refinery verifies patch identity and closes beads.
{{ end }}
