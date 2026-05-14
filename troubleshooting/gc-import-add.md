# `gc import add` issues

## Notes on Pack Imports

Local paths are treated differently depending on whether they're in a git worktree and whether they're committed to HEAD. The following table summarizes the different cases:

| Source location | `gc import add` works? | Notes | Example |
  | --- | --- | --- | --- |
  | Local path, not in any git worktree | ✅ | Plain-directory lane. Source stored as-is, no clone, no lock entry. | `mkdir -p /tmp/my-pack && printf '[pack]\nname="my-pack"\nschema=1\n' > /tmp/my-pack/pack.toml`<br>`cd ~/my-city`<br>`gc import add /tmp/my-pack` |
  | Local path in a git worktree, committed to HEAD | ✅ | Auto-promoted to `file://<repo>//<subpath>`, cloned at HEAD into `~/.gc/cache/repos/`. | `cd ~/shared-packs && git add packs/foo && git commit -m "add foo"`<br>`cd ~/my-city`<br>`gc import add ~/shared-packs/packs/foo`<br>*(stored as `file:///Users/you/shared-packs//packs/foo`)* |
  | Local path in a git worktree, not on HEAD (staged, untracked, or stashed) | ❌ | In order to import packs inside a git worktree without committing, manually add the `source = "path/to/pack"` entry to the `[imports.<binding>]` section of your `pack.toml` / `city.toml`. | Pack is uncommitted at `~/shared-packs/packs/foo`. Edit `~/my-city/pack.toml` and add:<br>`[imports.foo]`<br>`source = "/Users/you/shared-packs/packs/foo"`<br>then `gc import install` |
  | Remote git repo (`https://`, `ssh://`, `git@…`, bare `github.com/org/repo`) | ✅ | Standard `git clone`. Supports `--version` (semver or `sha:<commit>`). | `gc import add github.com/org/some-pack --version "^1.2.0"`<br>or<br>`gc import add git@github.com:org/some-pack.git --version "sha:abc1234"` |
  | Remote git repo subpath (`…/tree/<branch>/<sub>` or `file://repo//sub`) | ✅ | Clone URL + subpath parsed by `parsePackmanRemoteSource`. | `gc import add https://github.com/org/monorepo/tree/main/packs/foo`<br>or<br>`gc import add 'file:///Users/you/shared-packs//packs/foo'` |
