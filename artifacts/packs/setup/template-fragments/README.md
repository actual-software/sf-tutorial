# Vendored template fragments

This directory holds copies of five fragment files from the gastown pack. The polecat and refinery prompts in `setup`, and the refinery prompts of the rig packs built on it, call seven names those files define. A city built in this tutorial doesn't import gastown, so these copies are what resolves the names for every pack that imports `setup`. gc reads only the `.template.md` files here, which keeps this page and `LICENSE-gascity` out of every prompt.

## Source

All five came from gascity-packs, `gastown/template-fragments` at [`33d3a430`](https://github.com/gastownhall/gascity-packs/tree/33d3a430a67d1782ad364556cb566bdb01d0afe3/gastown/template-fragments) (2026-06-17). Four are byte-identical to that commit, and the fifth carries the local change described below.

| File | At `33d3a430` | Same bytes in a gascity revision |
|---|---|---|
| `approval-fallacy.template.md` | identical before the local change | [`fa38387d`](https://github.com/gastownhall/gascity/blob/fa38387dccdda0babf063d50d324e693f7546cda/examples/gastown/packs/gastown/template-fragments/approval-fallacy.template.md), before the local change |
| `architecture.template.md` | identical | [`9b802705`](https://github.com/gastownhall/gascity/blob/9b80270569a9f940e5fabc7d8bb21f5afb925162/examples/gastown/packs/gastown/template-fragments/architecture.template.md) |
| `capability-ledger.template.md` | identical | [`03754d1a`](https://github.com/gastownhall/gascity/blob/03754d1a8f03d954e9077b3a342e5a557313653d/examples/gastown/packs/gastown/template-fragments/capability-ledger.template.md) |
| `following-mol.template.md` | identical | [`e26e2045`](https://github.com/gastownhall/gascity/blob/e26e20451909e84e5dad8c33b8c31b363aab3271/examples/gastown/packs/gastown/template-fragments/following-mol.template.md) |
| `propulsion.template.md` | identical | none |

## License

gascity-packs has no license file. GitHub reports no license for the repository, and neither its root nor `gastown/` holds a LICENSE, COPYING or NOTICE file at [`520e95cb`](https://github.com/gastownhall/gascity-packs/tree/520e95cb22992a8a1017f7a60da267f203497c7e) (2026-10-08). The source states no terms for these files.

[`LICENSE-gascity`](LICENSE-gascity) is the MIT license of [gastownhall/gascity](https://github.com/gastownhall/gascity/blob/main/LICENSE). The gastown pack lived inside gascity, under `examples/gastown/packs/gastown/`, until [gascity#3335](https://github.com/gastownhall/gascity/pull/3335) moved it out on 2026-06-12. Four of the five files match a revision gascity shipped there under that license, as the table shows. `propulsion.template.md` matches none: the text copied here was last changed in gascity-packs on 2026-06-17, after the move. Whether gascity's MIT grant also covers gascity-packs is for that repository's maintainers to say.

## Local change

`approval-fallacy.template.md` differs from the source in the polecat's done sequence. The source restates the handoff commands, and the restatement never stamps `merge_strategy=pr`, so in a PR-gate rig the refinery would merge the work straight to the target branch with no pull request. Here the fragment points at the `submit-and-exit` step of the polecat's formula, which is the one copy of the done sequence. The source's `auto_push` opt-out and push check went with the restatement, and neither appears in this repo's polecat formulas. gascity-packs moved its own copy to the formula the same way in [`44b2eef9`](https://github.com/gastownhall/gascity-packs/commit/44b2eef94f035283b70df62d3bd1fc77bce13d56) ([gascity-packs#185](https://github.com/gastownhall/gascity-packs/pull/185)), with extra steps that depend on gastown's formulas.

To re-sync, copy the files from a newer gascity-packs commit, re-apply the change above, and update the commit and the table on this page.
