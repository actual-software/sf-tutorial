# W2 · Cloud Box and Preflight

**Workshop · 45 minutes · Day 1**

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context](#context)
- [The cloud box (recommended)](#the-cloud-box-recommended)
  - [Signing the box in with a token](#signing-the-box-in-with-a-token)
  - [Run preflight against the box](#run-preflight-against-the-box)
- [Running on your own machine (alternative)](#running-on-your-own-machine-alternative)
  - [1. Clone the tutorial](#1-clone-the-tutorial)
  - [2. Install the pinned dependencies](#2-install-the-pinned-dependencies)
  - [3. Run preflight](#3-run-preflight)
  - [4. Sign in to GitHub](#4-sign-in-to-github)
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

## The cloud box (recommended)

Getting onto the box is its own page. [`CLOUD_BOX_GUIDE.md`](../CLOUD_BOX_GUIDE.md) takes the four values your instructor sends you through to a running factory. Work through it first, then come back here for the preflight run below.

### Signing into the box with a token

The box holds its own GitHub credential, separate from the one on your laptop, and [step 5 of the box guide](../CLOUD_BOX_GUIDE.md#step-5-the-first-run-login) is where it gets one. That step asks which way you would like to give it:

```text
 GitHub sign-in. Two ways to give this box a credential:

   1. Browser sign-in. gh prints a short one-time code and a URL; you open it
      on any device, enter the code, and approve. Nothing is pasted back into
      this terminal. This grants the GitHub CLI repo, read:org, gist and
      workflow on your account.

   2. Paste a token you mint yourself. Choose this if you would rather not
      grant the CLI that access, or your organisation does not permit it. You
      will be asked for the token on the next line, and it stays on this box.

 Which route? [1]
```

A bare `Enter` takes the browser grant, which is what the rest of the guide assumes and what most of the room will take. Answering `2` prompts for a token instead. It is read without echoing, checked against GitHub before anything is written, and stored readable only by the factory user. Both routes then check that the account can actually read the repositories the box provisions from, so a credential that authenticates but cannot reach them fails at the prompt. If you would like to use a restricted grant token, be sure to mint it before you start step 5 and have it ready when the prompt appears.

If GitHub rejects it or you run into issues with the GitHub credential, nothing is written and first-run stops there rather than carrying on without a credential. Resume with `sudo gas-city-login --from github`, which redoes the sign-in and continues through the steps that had not run yet.

> [!NOTE]
> If you would like to change the credential later, run the following (or else it will refuse to drop the existing `gh` credential):
> ```bash
> ssh -t -F ~/.gascity/ssh_config "$SFI_BOX" gh auth logout --hostname github.com
> ssh -t -F ~/.gascity/ssh_config "$SFI_BOX" sudo gas-city-set-token
> ssh -t -F ~/.gascity/ssh_config "$SFI_BOX" sudo gas-city-refresh
> ```
> Alternatively, the following command on a box holding a pasted token offers the browser route and defaults to keeping the token:
> ```bash
> ssh -t -F ~/.gascity/ssh_config "$SFI_BOX" sudo gas-city-login github
> ```

On scopes, the two routes ask for the same thing. The browser grant yields `repo`, `read:org`, `gist` and `workflow`. The token prompt asks for a classic token with `repo`, plus `workflow` if any repository the agents touch carries GitHub Actions workflows, or a fine-grained one with contents and pull-requests read and write, plus workflows, on those repositories.

### Run preflight against the cloud box

**Copy and paste**

```bash
cd bootstrap
./preflight.sh --cloud
```

`--cloud` runs every local check first and then adds a "Cloud path" section.

**Expected output**

```text
Cloud path
  [ ok ] sfbox: /path/to/sf-tutorial/participant-box-cli/sfbox
  [ ok ] box credential: <boxId>
  [ ok ] box reachable: ssh, gc and the Gas City service all answered

PREFLIGHT: PASS
```

## Running on your own machine (alternative)

Everything below is the fallback if you would like to run the curriculum on your local machine. If you are on an instructor-provided cloud box, skip to [What's next](#whats-next).

### 1. Clone the tutorial

**Copy and paste**

```bash
cd $HOME && mkdir software-factory-intensive
cd software-factory-intensive
export SOFTWARE_FACTORY_INTENSIVE_PATH="$(pwd)"
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
three version lines, then: Installed to <your-home>/.local/bin. Ensure it's on your PATH:
```

Do what that last line says if you have not already:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then, add the variables to `~/.zshrc` or `~/.bashrc` too so new session windows contain it:

**Copy and paste** (macOS / zsh)

```bash
cat <<EOF >> ~/.zshrc
export SOFTWARE_FACTORY_INTENSIVE_PATH="$SOFTWARE_FACTORY_INTENSIVE_PATH"
export PATH="$HOME/.local/bin:$PATH"
EOF
```

**Copy and paste** (Linux / bash)

```bash
cat <<EOF >> ~/.bashrc
export SOFTWARE_FACTORY_INTENSIVE_PATH="$SOFTWARE_FACTORY_INTENSIVE_PATH"
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
  ...
  [ ok ] gh auth: authenticated

Pinned dependencies
  [ ok ] PATH includes <your-home>/.local/bin
  [ ok ] bd: 1.1.0 (pinned)
  [ ok ] dolt: 2.2.2
  [ ok ] gc: 1.4.0 (at or above the pinned 1.4.0)

Dolt identity
  [ ok ] dolt identity: Your Name <you@example.com>

Local path
  [ ok ] home directory is writable

PREFLIGHT: PASS
```

### 4. Sign in to GitHub

This step signs in *the machine you type on*. A hosted box keeps its own separate GitHub credential and offers the same choice by a different command, covered in [Signing the box in with a token](#signing-the-box-in-with-a-token).

The `gh auth` check is the one line in preflight that needs your GitHub account. `gh auth login`, picking HTTPS, is the shortest route. It opens a browser and authorizes the GitHub CLI against your whole account.

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
