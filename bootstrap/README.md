# Bootstrap Scripts

This folder contains the bootstrap scripts for the Software Factory Intensive tutorial.


> **Two tracks, two vocabularies.** `W3-run-your-factory` is the taught path, and it installs the `base-factory` pack in one import the way [W3](../progression/W3-run-your-factory.md) has you do it by hand. The `00.1` through `05.2` names are the [appendix pages](../appendix/README.md), which assemble the same factory one pack at a time. Pick the track you are working through; they are different sequences rather than two halves of one.

## Instructions

1. Set up your environment variables

	```bash
	cp .env.example .env
	```

   Open `.env` with `nano .env` and follow the instructions in the code comments to update your settings. `nano` ships with the box and is not modal: `Ctrl-O` then `Enter` saves, and `Ctrl-X` exits. Swap in a different editor if you already have one you prefer.

2. Install the pegged versions of `bd`, `dolt` and `gc`. The pins are declared in `deps.sh`, which is the one place they live. Read them there rather than from this page, so there is only one copy to keep current. `bd` and `dolt` arrive as release archives; `gc` is built from source at a pinned commit, so budget a few minutes for the first run and expect a later one to skip the build.

	```bash
	chmod +x deps.sh
	./deps.sh
	```	

3. Run the bootstrap script to fast-forward your `factory1` instance to the **state at the end of** a given lesson. The script runs the setup work for every step up to and including the one you pass, leaving you in the post-lesson state — ready to verify that lesson's outcome or move on to the next one.

	```bash
	chmod +x bootstrap.sh
	./bootstrap.sh <TUTORIAL_STEP>
	```

   The steps come in two tracks. `W3-run-your-factory` is the taught path, and the one to reach for when Day 1 ended somewhere you would rather not start Day 2 from. It leaves you at the end of [W3](../progression/W3-run-your-factory.md): the city running, the `ascii-art` rig pushed to GitHub, the `base-factory` pack installed at rig scope, `pr-gate-city` at city scope with the mayor handed over to it, and the beads queue seeded. The rest are the [appendix](../appendix/README.md) lessons, in order:

   - `00.1-setup-foundation`
   - `00.2-setup-foundation`
   - `00.3-setup-foundation`
   - `01-basic-flow`
   - `02-first-review-loop`
   - `03-branch-protection`
   - `04-adr-reviewer`
   - `05.1-bead-gate-checks`
   - `05.2-bead-gate-checks`

   Pass anything that is not on that list and the script prints the list and exits 1. It checks the argument before it deletes anything, so a typo costs you nothing.

For example:

```bash
# Nuke the factory and rebuild it to the state at the end of W3
./bootstrap.sh W3-run-your-factory
```

Tears the workspace down, recreates `factory1` and the `ascii-art` rig, installs the base factory, seeds the beads queue and starts the city. Day 2 begins from there, whatever Day 1 left behind.

```bash
# Rebuild to the state at the end of appendix lesson 01
./bootstrap.sh 01-basic-flow
```

Runs the setup work for 00.1, 00.2 and 00.3 on the way past, then stops at the end of 01. Your factory now looks like it would after you had worked through 01 by hand, so you can inspect that state or start 02 from a clean baseline.

**Mental model:** `./bootstrap.sh <step>` answers "make my factory look like I just finished `<step>`," not "make my factory ready for me to start `<step>`."

**Nothing to paste afterwards.** `$SFI_PATH` is the only path variable the curriculum asks for, and [W2](../progression/W2-cloud-box-and-preflight.md) and [W3](../progression/W3-run-your-factory.md) both append it to a shell rc. The script works out the factory, rig and artifact directories from it for its own use; every page writes them out the same way, so a run leaves your shell with nothing new to set.

## About the Bootstrap Script

### Running the script

Run this script from this folder to bootstrap your factory into the **end state** of a given lesson. Pass the tutorial step as the first argument; the script runs that step's setup and every earlier step's setup, cumulatively.

### How a run reports success

A finished run prints `==> Ready to test on <step>` and exits 0, so you can chain `./bootstrap.sh <step> && <next thing>`.

The banner appears only after the script confirms your city actually came up. Earlier versions printed it straight after `gc start` without checking anything, so a run whose city never started still reported success. The script now reads two signals: the `fatal=` field in the `gc start` output, which names the failure, and the controller line from `gc status`, which confirms the city is live. Both are more specific than the exit code on its own, and the second also catches a city that starts but never becomes ready. A run that fails either one says what went wrong and exits 1, with no banner.

The wait for the city is 60 seconds. Raise it on a slow machine:

```bash
CITY_READY_TIMEOUT=180 ./bootstrap.sh 01-basic-flow
```

### What it does to your environment

This script is destructive and meant to be re-runnable. **If you made any changes/customizations you want to keep, Make sure you pack them up somewhere Before running this.** Read this before your first run.

**Confirmation prompt.** On launch, you'll see:

```
Are you comfortable with resetting all of $SFI_PATH? (Y/n)
```

You must type a **capital `Y`** to continue — `y`, `yes`, or just pressing Enter all abort the script. Nothing has been deleted at the prompt.

**What gets `rm -rf`'d on every run.** Inside `$SFI_PATH` only:

- `factory*/` — every directory whose name starts with `factory` (e.g. `factory1`, `factory2`)
- `ascii-art/`

`sf-tutorial/` stays. The script lives inside that repo, so you already have it, and a run that deleted it would be deleting itself.

Anything outside `$SFI_PATH` is untouched. Anything inside it that doesn't match those names (e.g. `mp-skills/`, pulled by step 05.2) is also untouched.

**Other cleanup the script performs.**

- Runs `gc stop` on every `factory*` city listed by `gc cities` before deleting their directories.
- Does **not** run `gc unregister`. Stale registrations may linger in Gas City state, but the directories themselves are removed.
- For step 00.2 and later, if `$GITHUB_USERNAME/ascii-art` exists on GitHub, the script deletes the `main` branch protection rule and the "Epic branches require human review" ruleset on the remote (step 03 re-applies them).
- Any existing `.beads/issues.jsonl` in each rig is **moved** to `/tmp/{rig_name}-issues-backup-{timestamp}.jsonl` — backed up, not deleted.

### Switching between steps is safe and re-runnable

The end state is determined entirely by the argument you pass, not by any prior run. Every invocation tears the workspace down to the same baseline before rebuilding.

- Completed lesson 04 manually, then ran `./bootstrap.sh 02-first-review-loop`? The script blows everything away and brings you to the end-of-02 state.
- Want to get back to end-of-04? Run `./bootstrap.sh 04-adr-reviewer` again — same teardown, rebuild stops at 04.
- Day 1 left your factory somewhere you would rather not start Day 2 from? `./bootstrap.sh W3-run-your-factory` puts you back at the end of W3 with the base factory installed.

There's no "incremental" mode — every run is a full reset followed by replaying setup up to the requested step.
