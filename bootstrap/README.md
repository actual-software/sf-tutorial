# Bootstrap Scripts

This folder contains the bootstrap scripts for the Software Factory Intensive tutorial.

## Dependencies Script

This script will install particular pegged versions of `bd` (1.0.3) and `dolt` (2.0.1).

To run the script, simply make the script executable and run it from this folder.

```bash
chmod +x deps.sh
./deps.sh
```

## Bootstrap Script

### Environment Variables

This script has some configuration you must set first in `.env`. Please check out `.env.example` for a full example with notes of what to choose.

### Running the script

Run this script from this folder to bootstrap your factory to be ready to execute a given lesson. Pass the tutorial step as the first argument.

```bash
chmod +x bootstrap.sh
./bootstrap.sh <TUTORIAL_STEP>
```

For example:

```bash
./bootstrap.sh 00.2-setup-foundation
```
