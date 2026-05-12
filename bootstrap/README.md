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
3. Run the bootstrap script to set up your instance of `factory1` through a given lesson.

	```bash
	chmod +x bootstrap.sh
	./bootstrap.sh <TUTORIAL_STEP>
	```

For example:

	```bash
	./bootstrap.sh 00.2-setup-foundation
	``` 

## Bootstrap Script

### Running the script

Run this script from this folder to bootstrap your factory to be ready to execute a given lesson. Pass the tutorial step as the first argument.

