# Bootstrap Scripts

This folder contains the bootstrap scripts for the Software Factory Intensive tutorial.

## Instructions

1. Set up your environment variables

	```bash
	cp .env.example .env
	```

   Open `.env` And follow the instructions in code comments to update your settings.

2. Install particular pegged versions of `bd` (1.0.3) and `dolt` (2.0.1).

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
	./bootstrap.sh 00.2-setup-foundation
	```

	Runs the work for 00.1 *and* 00.2, then stops. Your factory now looks like it would after you'd manually completed 00.2 — so you can inspect that state, or start 00.3 from a clean baseline.

**Mental model:** `./bootstrap.sh <step>` answers "make my factory look like I just finished `<step>`," not "make my factory ready for me to start `<step>`."

## Bootstrap Script

### Running the script

Run this script from this folder to bootstrap your factory into the **end state** of a given lesson. Pass the tutorial step as the first argument; the script runs that step's setup and every earlier step's setup, cumulatively.

