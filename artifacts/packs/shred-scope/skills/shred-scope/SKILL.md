---
name: shred-scope
description: Turn a project scope document, such as the docs/PROJECT_MANIFEST.md written in L1, into one bd epic plus child beads a Gas City factory can work. Each child is sized for one polecat run and carries metadata.target_file and an acceptance check, with bd dep edges wherever one child needs another's output. Use when asked to shred, break down or decompose a scope, manifest, spec or feature list into beads. Proposes the plan first, writes nothing until the person says yes, and never slings.
---

# Shred a scope into beads

You turn one scope document into work a factory can pick up: an epic for the scope, child tasks under it, and dependency edges between the children. The beads you write have to pass the bead gate from the tutorial's `hardening/06` lab (the project-manager's checklist) with no edits, so every rule below comes from that checklist.

You propose before you write: nothing touches the bead store until the person's read your plan and said yes. You don't sling beads, and you don't write code.

## Inputs

- **The scope doc.** A path. Read all of it.
- **The rig.** The registered rig the beads belong to. Use the one the person names. Otherwise run `gc rig list` and take the rig whose path holds the scope doc. If neither settles it, ask. Don't guess.

Every `bd` command here goes through `gc bd --rig <rig>`, which runs bd in that rig's directory, so the beads land in the rig's store wherever you're standing. A bead written to the city's store won't ever reach the rig's polecat.

## 1. Find the work

Look for the section that says what to build. It's usually a heading such as Scope, Goals, Milestone, Roadmap, Features, Deliverables or Backlog, and a manifest from the manifest generator keeps its features under Success Criteria, in Per-Feature Success. The rest is context: the stack, how the tests run, what must never break, the conventions, and which paths a change touches.

If no section names work to do, stop. Say which sections you read, and ask for a short Scope section listing what should be built. A document that only describes a project has nothing to shred, and inventing scope is exactly the failure this skill's here to prevent.

When the work comes from a list of criteria instead of an explicit scope, some items may already exist. Look in the repository for the files they imply, and ask which items are still to build before you go on.

## 2. Cut it into children

One child is one polecat run: a single target file, a change a reviewer can read in a few minutes, and one check that says it's done. Split anything bigger. Merge two children that would edit the same file for the same reason.

- **At most 12 children per epic.** If the scope needs more, propose several epics first, each a coherent slice of 12 or fewer, and shred one epic per run.
- **A dependency means one child reads another child's output**: a file it copies, a function it calls, a schema it fills in. Add an edge for that and nothing else. An edge keeps the dependent out of `bd ready` until the other child closes, so a preference about order is not a dependency.
- **No cycles.** Two children that each need the other are one child.

## 3. Write each bead so the gate passes it

The project-manager reads a bead's title, description and metadata, and blocks it when any of these checks fails. Write to them:

| Check | Child task | Epic |
|---|---|---|
| Title is meaningful | Names the deliverable, such as `Implement 3.md`. Never `TODO` or a bare id. | Names the scope. |
| Description names a concrete deliverable | Which file is created or changed, and what goes in it. | What the scope delivers. |
| `metadata.target_file` is set | One repository-relative path: the file the polecat writes. | Not needed. |
| Title and `target_file` agree | The file the title names is the `target_file`. | |
| Parent epic exists and is open | Created with `--parent <epic>`. | |
| Description names an outcome a test could assert | Ends with a `Done when:` line a reviewer can check by running a command or reading one file. | |
| Has at least one child | | You create the children in the same run. |

Take each `Done when:` line from the scope doc: its test command, its "must never break" rules, the decision record a file has to follow. "Works well" and "is consistent" can't be checked. "`grep -c '^# ' ascii/3.md` prints 1" can.

## 4. Propose, then wait

Before any write, show the person:

1. The rig, and the prefix its bead ids carry (`gc rig list` prints it).
2. The epic's title and a one-line description.
3. A table of the children: number, title, `target_file`, `Done when:`, and which children it needs.
4. The dependency edges, one per line, such as `6 needs 1`.
5. Anything you assumed or left out, and why.

Then ask **Create these beads? (yes / change something / no)** and stop. Run no `bd create` and no `bd dep add` until the answer is yes. If they ask for a change, redraw the plan and ask again.

## 5. Create them

First make sure you aren't writing a duplicate. If an open epic with the same title is already in the rig, show it and ask before you create another:

```bash
gc bd --rig <rig> list --type=epic --json | jq -r '.[] | "\(.id)\t\(.status)\t\(.title)"'
```

Write each description to a file with a quoted heredoc, because a backtick inside a double-quoted shell string runs as a command and these descriptions are full of backticks.

```bash
D=$(mktemp -d)

cat > "$D/epic.md" <<'EOF'
<what the scope delivers, in a sentence or two>
EOF
EPIC=$(gc bd --rig <rig> create --type=epic --priority=2 \
  --metadata '{"scope_doc":"<path of the scope doc>"}' \
  --body-file "$D/epic.md" \
  --json "<epic title>" | jq -r .id)
echo "epic: $EPIC"
```

Before you create any child, check that `$EPIC` starts with the rig's prefix. If it doesn't, the write reached a different store, so stop and say so.

Then each child, keeping every id you get back:

```bash
cat > "$D/c1.md" <<'EOF'
<the deliverable: which file, and what goes in it>

Done when: <the check>
EOF
C1=$(gc bd --rig <rig> create --type=task --parent="$EPIC" --priority=2 \
  --metadata '{"target_file":"<path>"}' \
  --body-file "$D/c1.md" \
  --acceptance "$(sed -n 's/^Done when: //p' "$D/c1.md")" \
  --json "<title>" | jq -r .id)
echo "child 1: $C1"
```

Then one edge per dependency. `dep add A B` means A needs B:

```bash
gc bd --rig <rig> dep add "$C6" "$C1"
```

If a command fails, stop and report what exists so far. Don't re-run a create: a retry makes a duplicate.

## 6. Check it and hand back

```bash
gc bd --rig <rig> list --parent "$EPIC"
gc bd --rig <rig> list --parent "$EPIC" --json \
  | jq -r '.[] | "\(.id)\t\(.metadata.target_file // "MISSING")\t\(.title)"'
gc bd --rig <rig> dep list "$C6"
```

Every child should show a `target_file`, and every edge you proposed should be there. Then report the epic id, each child's id and `target_file`, the edges, and which children are ready now versus waiting on another.

End with the next step, and leave it to the person: they can send one child through the bead gate from `hardening/06`, or sling it to the polecat on the PR path.

```bash
gc sling --rig <rig> polecat <child-id> --on mol-polecat-pr
```

## Never

- Sling, claim or close a bead, or edit one you didn't create in this run.
- Write code, or edit the scope doc.
- Put more than 12 children under one epic.
- Write anything before the person says yes.
