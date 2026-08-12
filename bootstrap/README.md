# Bootstrap Scripts

This folder contains the bootstrap scripts for the Software Factory Intensive tutorial.

## Instructions

1. Set up your environment variables

	```bash
	cp .env.example .env
	```

   Open `.env` And follow the instructions in code comments to update your settings.

2. Install the pegged versions of `bd` and `dolt`. The pins are declared in `deps.sh`, which is the one place they live. Read them there rather than from this page, so there is only one copy to keep current.

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

## About the Bootstrap Script

### Running the script

Run this script from this folder to bootstrap your factory into the **end state** of a given lesson. Pass the tutorial step as the first argument; the script runs that step's setup and every earlier step's setup, cumulatively.

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
