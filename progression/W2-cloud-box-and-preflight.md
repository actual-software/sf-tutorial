# W2 · Cloud Box and Preflight

**Workshop · 45 minutes · Day 1**

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context](#context)
- [Shared setup](#shared-setup)
  - [1. Clone the tutorial](#1-clone-the-tutorial)
  - [2. Install the pinned dependencies](#2-install-the-pinned-dependencies)
  - [3. Run preflight](#3-run-preflight)
- [The cloud box (recommended)](#the-cloud-box-recommended)
  - [Run preflight locally once complete](#run-preflight-locally-once-complete)
  - [How you will drive the box](#how-you-will-drive-the-box)
- [Running on your own machine (alternative)](#running-on-your-own-machine-alternative)
  - [1. Sign in to GitHub](#4-sign-in-to-github)
- [Troubleshooting](#troubleshooting)
- [What's next](#whats-next)

## Objective

By the end of this session `./preflight.sh` prints `PREFLIGHT: PASS` wherever you are going to work, which means every dependency the rest of the curriculum needs is installed at the version it was written against.

## Prereqs

- MacOS or Linux (or Windows with [WSL](https://learn.microsoft.com/en-us/windows/wsl/install)) installed if running the software factory locally (the cloud box is preconfigured for Linux)
- A GitHub account with the ability to create new repositories.

## Context

Nothing in the rest of the curriculum works until the preflight check passes, and the failures it catches are all cheaper to find now than at step nine of the next session.

Most participants should work on an instructor-provided cloud box, which is the path below. Your own machine works too, and that path is in the appendix at the end of this page. Do one of them, not both.

## Shared setup

Regardless of whether you choose to run the factory in our instructor-provided cloud box or your local machine, you will need to have gas city dependencies installed locally to build the factory packs and run checks correctly.

### 1. Clone the tutorial

**Copy and paste**

```bash
cd $HOME && mkdir software-factory-intensive
cd software-factory-intensive
export SFI_PATH="$(pwd)"
git clone https://github.com/actual-software/sf-tutorial.git
cd sf-tutorial/bootstrap
```

### 2. Install the pinned dependencies

`deps.sh` installs `bd`, `dolt` and `gc` at the pinned versions into `~/.local/bin`. `bd` and `dolt` are downloaded as release archives and checksum-verified; `gc` has no release archive, so it is built from source at a pinned commit. Expect the first run to spend a few minutes on that build. A later run skips it once the installed `gc` reports the pinned commit, so re-running the script is cheap.

**Copy and paste**

```bash
chmod +x deps.sh preflight.sh
./deps.sh
```

**Expected output**

```text
beads_1.1.0_darwin_arm64.tar.gz: OK
Building gc 1.4.0 from gastownhall/gascity at a7297c511. This takes a few minutes.
go build -ldflags "-X main.version=1.4.0 -X main.commit=a7297c511 -X main.date=2026-08-18T07:39:52Z" -o bin/gc ./cmd/gc
No stable macOS signing identity found; leaving Go linker signature unchanged for gc.
Set GC_SIGN_IDENTITY='<certificate name>' for persistent local TCC grants.
Symlinked /Users/austin/.local/bin/gc -> /Users/austin/go/bin/gc
Installed gc to /Users/austin/go/bin/gc
bd version 1.1.0 (8e4e59d39)
dolt version 2.2.2
```

Export the `$PATH` variable for the local `gc` runtime:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then, add the variables to `~/.zshrc` or `~/.bashrc` too so new session windows contain it:

**Copy and paste** (macOS / zsh)

```bash
cat <<EOF >> ~/.zshrc
export SFI_PATH="$SFI_PATH"
export PATH="$HOME/.local/bin:$PATH"
EOF
```

**Copy and paste** (Linux / bash)

```bash
cat <<EOF >> ~/.bashrc
export SFI_PATH="$SFI_PATH"
export PATH="$HOME/.local/bin:$PATH"
EOF
```

### 3. Run preflight

**Copy and paste**

```bash
./preflight.sh
```
**Expected output**

```text
Platform
  [ ok ] os: darwin
  [ ok ] arch: arm64

Required tools
  [ ok ] git: /usr/bin/git
  [ ok ] tmux: /opt/homebrew/bin/tmux
  [ ok ] curl: /usr/bin/curl
  [ ok ] jq: /usr/bin/jq
  [ ok ] gh: gh version 2.97.0 (2026-07-31)
  [ ok ] gh auth: authenticated

Pinned dependencies
  [ ok ] PATH includes /Users/austin/.local/bin
  [ ok ] bd: 1.1.0 (pinned)
  [ ok ] dolt: 2.2.2
  [ ok ] gc: 1.4.0 (at or above the pinned 1.4.0)

Dolt identity
  [ ok ] dolt identity: Austin Born <austin@shinzolabs.com>

Local path
  [ ok ] workspace: /Users/austin/software-factory-intensive
  [ ok ] home directory is writable

PREFLIGHT: PASS
```

## The cloud box (recommended)

Follow [`CLOUD_BOX_GUIDE.md`](../CLOUD_BOX_GUIDE.md) from here once you have cloud box credentials from the instructor.

### Run preflight locally once complete

**Copy and paste**

```bash
sfbox preflight
```

**Expected output**

```text
==> Checking 'factory-cloud-aborn-2' (ubuntu@34.200.237.69) ...
==>   ssh            reachable
==>   gc             installed
==>   gas-city.service  inactive — no city on this box yet
==>   Nothing is broken. This box supplies the environment and you build the
==>   city yourself, so the service stays down until there is one to run.
```

### How you will drive the box

The factory you build in [W3](./W3-run-your-factory.md) lives on the box, and you drive it from your laptop. `sfbox exec <command>` runs any command there. `sfbox gc <args>` runs a `gc` command inside the box's city once there is one, so you never have to remember where the city lives. When you would rather work on the box directly, `sfbox start-session` opens a full shell.

**Copy and paste**

```bash
sfbox exec systemctl is-active gas-city.service
```

**Expected output**

```text
inactive
```

`inactive` is the right answer today, and the same thing preflight just told you in more words: there is no city on the box yet, so the service has nothing to supervise. W3 is where you build it one.

## Running on your own machine (alternative)

### 1. Sign in to GitHub

If you are not currently logged into GitHub, you will need to grant your software factory access to configure repos and push code.`gh auth login`, picking HTTPS, is the shortest route to login if necessary. It opens a browser and authorizes the GitHub CLI against your whole account.

If you would rather not grant that, paste a personal access token instead. Both kinds of token work, but they go in by different commands and the two are not interchangeable.

**Classic token.** Create one under [Settings → Developer settings → Tokens (classic)](https://github.com/settings/tokens) with the `repo`, `read:org`, and `gist` scopes, then read it in from a file:

```bash
gh auth login --with-token < your-token-file
```

Grant it **Contents**, **Pull requests**, and **Administration**, all write, on the repository you will push the rig to. Administration is the one that is easy to miss — [the branch-protection appendix](../appendix/03-branch-protection.md) needs it to install branch protection, and that failure lands an hour into day one. A fine-grained token also has to name a repository that already exists, and the rig's repository is created on [W3 Run Your Factory](./W3-run-your-factory.md), so either create it now or come back and re-scope the token then.

**Either token needs one more command.** `--with-token` and `GH_TOKEN` both authenticate `gh` without telling `git` anything, so `git push` still fails with `could not read Username for 'https://github.com'`. The browser flow wires this up for you and the token routes do not:

```bash
gh auth setup-git
```

## Troubleshooting

- **`PATH is missing ~/.local/bin`.** Run `export PATH="$HOME/.local/bin:$PATH"`, then add the same line to your shell rc so a new terminal keeps it.
- **`gh auth: not authenticated`.** Run `gh auth login` and pick HTTPS, or paste a personal access token — [Sign in to GitHub](#4-sign-in-to-github) covers both token types and the `gh auth setup-git` step they need. You need this before the rig gets pushed, which happens in the first hands-on block.
- **`bd: not found` right after `deps.sh` said it installed.** Almost always the `PATH` problem above. Confirm with `ls ~/.local/bin`.
- **A checksum mismatch during `deps.sh`.** A partial download. Re-run it; the script fetches to a temporary directory and cleans up after itself.
- **`gc: not found`, or a `gc` older than the pin.** Run `./deps.sh`, which builds `gc` at the pinned commit. The build needs Go on your `PATH` — install it from [go.dev/dl](https://go.dev/dl/) first if the script says so. A `gc` *newer* than the pin passes: the check is a floor, not an exact match.
- **`dolt identity: … unset`.** A warning, not a failure. `bootstrap.sh` sets it from your `GITHUB_USERNAME`. If you are working through the pages by hand instead, set it yourself: `dolt config --global --add user.name "<your name>"` and the same for `user.email`.
- **`dolt` reports a different version than the pin.** That is a warning rather than a failure. It will probably work; mention it to an instructor so it can be ruled out if a later step misbehaves.

## What's next

You are set up. [W3](./W3-run-your-factory.md) is where the factory gets built: a city, a rig on GitHub, the base factory pack, and your first bead moving through it while you watch.

« [previous: W1 Vocabulary and Concepts](./W1-vocabulary-and-concepts.md) | [next: W3 Run Your Factory](./W3-run-your-factory.md) »
