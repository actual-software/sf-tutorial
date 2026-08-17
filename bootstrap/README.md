# Bootstrap Scripts

This folder contains the bootstrap scripts for the Software Factory Intensive tutorial.

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

For example:

	```bash
    # This will set up your factory to be ready to use the examples in 01-basic-flow
	./bootstrap.sh 01-basic-flow
	```

Runs the work for 00.1 *and* 00.2, then stops. Your factory now looks like it would after you'd manually completed 00.2 — so you can inspect that state, or start 00.3 from a clean baseline.

**Mental model:** `./bootstrap.sh <step>` answers "make my factory look like I just finished `<step>`," not "make my factory ready for me to start `<step>`."

**Then paste the export block the run prints.** The script sets `FACTORY_PATH`, `ASCII_ART_PATH`, `TUTORIAL_PATH` and `ARTIFACTS_PATH` in its own child process, so they do not reach the shell you launched it from. Every run ends by printing them in paste-ready form; do that before you continue, and before you append them to a shell rc on [W3 Run Your Factory](../progression/W3-run-your-factory.md).

## About the Bootstrap Script

### Running the script

Run this script from this folder to bootstrap your factory into the **end state** of a given lesson. Pass the tutorial step as the first argument; the script runs that step's setup and every earlier step's setup, cumulatively.

### How a run reports success

A finished run prints `==> Ready to test on <step>`, then the export block described above, and exits 0, so you can chain `./bootstrap.sh <step> && <next thing>`.

The banner appears only after the script confirms your city actually came up. Earlier versions printed it straight after `gc start` without checking anything, so a run whose city never started still reported success. The script now reads two signals: the `fatal=` field in the `gc start` output, which names the failure, and the controller line from `gc status`, which confirms the city is live. Both are more specific than the exit code on its own, and the second also catches a city that starts but never becomes ready. A run that fails either one says what went wrong and exits 1, with no banner.

The wait for the city is 60 seconds. Raise it on a slow machine:

```bash
CITY_READY_TIMEOUT=180 ./bootstrap.sh 01-basic-flow
```

### What it does to your environment

This script is destructive and meant to be re-runnable. **If you made any changes/customizations you want to keep, Make sure you pack them up somewhere Before running this.** Read this before your first run.

**Confirmation prompt.** On launch, you'll see:

```
Are you comfortable with resetting all of $SOFTWARE_FACTORY_INTENSIVE_PATH? (Y/n)
```

You must type a **capital `Y`** to continue — `y`, `yes`, or just pressing Enter all abort the script. Nothing has been deleted at the prompt.

**What gets `rm -rf`'d on every run.** Inside `$SOFTWARE_FACTORY_INTENSIVE_PATH` only:

- `factory*/` — every directory whose name starts with `factory` (e.g. `factory1`, `factory2`)
- `ascii-art/`
- `sf-tutorial/`

Anything outside `$SOFTWARE_FACTORY_INTENSIVE_PATH` is untouched. Anything inside it that doesn't match those names (e.g. `mp-skills/`, pulled by step 05.2) is also untouched.

**Other cleanup the script performs.**

- Runs `gc stop` on every `factory*` city listed by `gc cities` before deleting their directories.
- Does **not** run `gc unregister`. Stale registrations may linger in Gas City state, but the directories themselves are removed.
- For step 00.2 and later, if `$GITHUB_USERNAME/ascii-art` exists on GitHub, the script deletes the `main` branch protection rule and the "Epic branches require human review" ruleset on the remote (step 03 re-applies them).
- Any existing `.beads/issues.jsonl` in each rig is **moved** to `/tmp/{rig_name}-issues-backup-{timestamp}.jsonl` — backed up, not deleted.

### Switching between steps is safe and re-runnable

The end state is determined entirely by the argument you pass, not by any prior run. Every invocation tears the workspace down to the same baseline before rebuilding.

- Completed lesson 04 manually, then ran `./bootstrap.sh 02-first-review-loop`? The script blows everything away and brings you to the end-of-02 state.
- Want to get back to end-of-04? Run `./bootstrap.sh 04-adr-reviewer` again — same teardown, rebuild stops at 04.

There's no "incremental" mode — every run is a full reset followed by replaying setup up to the requested step.
