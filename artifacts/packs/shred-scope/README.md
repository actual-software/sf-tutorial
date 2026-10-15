# shred-scope

One skill for your factory's agents. Give it a scope document, such as the `docs/PROJECT_MANIFEST.md` you wrote in [L1](../../../progression/L1-plan-your-factory.md), and it cuts the work into one epic and child beads: each child sized for a single polecat run, each carrying `metadata.target_file` and a `Done when:` check, with a `bd dep add` edge wherever one child needs another's output. The children are written to pass the [bead gate](../../../hardening/06-bead-gate-checks.md)'s project-manager as they stand.

The skill shows you the whole plan before it writes anything, creates the beads only after you say yes, and never slings.

The lab that teaches it is [hardening/07](../../../hardening/07-shred-a-scope-into-beads.md).

## Contents

| Path | Purpose |
| --- | --- |
| `skills/shred-scope/SKILL.md` | The skill. gc discovers it by convention, with no `pack.toml` key, and names it `<binding>.shred-scope`. |
| `examples/PROJECT_MANIFEST.md` | A manifest filled in for `ascii-art`, ending in a small scope: the numbers 1 to 5 and a gallery page that needs them. |

## Install

Import it at **city** scope, from the city directory, so the mayor gets the skill:

```bash
cd "$SFI_PATH/factory1"
gc import add "$SFI_PATH/sf-tutorial/artifacts/packs/shred-scope"
gc reload
gc skill list --agent mayor | grep shred-scope
```

The last line should print one row naming `shred-scope.shred-scope`. A city-scope import reaches every agent in the city, the mayor included. A rig-scope import (`--rig <rig>`) would reach only that rig's agents, which leaves out the mayor.

## Use

Attach to the mayor with `gc session attach mayor` and ask, naming your own scope doc and rig:

> Use the shred-scope skill on docs/PROJECT_MANIFEST.md in the ascii-art rig.

Read the plan it shows you, then answer `yes`. Detach with `Ctrl-b` then `d`.

## Two things to know

- **Codex on gc v1.4.0 gets no pack skills.** That build writes them to `.codex/skills`, a directory Codex never reads, so the skill never reaches the agent. Newer gc builds, including the one on the cloud box, write to `.agents/skills`. Claude gets the skill on either build.
- **The import is pinned to a commit.** Because this pack sits inside your `sf-tutorial` clone, which is a git repository, `gc import add` records the clone's current commit, and agents read the skill from that commit, not from your working tree. A new commit doesn't move that lock, and neither does `gc import upgrade`, so remove the import and add it again to pick up a committed change. While you're editing the skill, copy the pack somewhere outside git and import the copy instead, so an edit to `SKILL.md` reaches agents with no commit at all.
