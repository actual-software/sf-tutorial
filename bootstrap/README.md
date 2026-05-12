# Bootstrap Scripts

This folder contains the bootstrap scripts for the Software Factory Intensive tutorial.

## Dependencies Script

To run the script, first please fill out the `.env` file in this folder with the correct values, then make the script executable and run it.

```bash
chmod +x deps.sh
./deps.sh
```

## Bootstrap Script

### Environment Variables


Then source the `.env` file. Then run the script.

### Running the script

Run this script to bootstrap your factory to be ready to execute a given lesson. Pass the tutorial step as the first argument.

```bash
c
./bootstrap.sh <TUTORIAL_STEP>
```

For example:

```bash
./bootstrap.sh 00.2-setup-foundation
```
