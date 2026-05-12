# Bootstrap Scripts

This folder contains the bootstrap scripts for the Software Factory Intensive tutorial.

## Dependencies Script

Run this script to install the dependencies for the tutorial.

```bash
./deps.sh
```

## Bootstrap Script

### Environment Variables

To run the script, first please fill out the `.env` file in this folder with the correct values.

```bash
.env.example
```

### Running the script

Run this script to bootstrap your factory to be ready to execute a given lesson. Pass the tutorial step as the first argument.

```bash
./bootstrap.sh <TUTORIAL_STEP>
```

For example:

```bash
./bootstrap.sh 00.2-setup-foundation
```
