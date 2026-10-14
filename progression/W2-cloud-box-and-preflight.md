# W2 · Cloud Box and Preflight

**Workshop · 45 minutes · Day 1**

## Contents

- [Objective](#objective)
- [Prereqs](#prereqs)
- [Context](#context)
- [The cloud box (recommended)](#the-cloud-box-recommended)
  - [1. Get onto your box](#1-get-onto-your-box)
  - [2. Check the box](#2-check-the-box)
  - [3. Set up your workspace on the box](#3-set-up-your-workspace-on-the-box)
- [Your own machine (alternative)](#your-own-machine-alternative)
  - [1. Install the tools](#1-install-the-tools)
  - [2. Clone the tutorial](#2-clone-the-tutorial)
  - [3. Install gc, bd and dolt](#3-install-gc-bd-and-dolt)
  - [4. Sign in to your coding agent](#4-sign-in-to-your-coding-agent)
  - [5. Sign in to GitHub](#5-sign-in-to-github)
  - [6. Run preflight](#6-run-preflight)
- [Troubleshooting](#troubleshooting)
  - [On the cloud box](#on-the-cloud-box)
  - [On your own machine](#on-your-own-machine)
- [What's next](#whats-next)

## Objective

By the end of this session you have one terminal that [W3](./W3-run-your-factory.md) can start from, on your cloud box or on your own machine. In it, `gc`, `bd` and `dolt` are installed, your coding agent and GitHub are signed in, and this tutorial is cloned into the workspace that `$SFI_PATH` names.

## Prereqs

- A GitHub account that can create repositories.
- An account for at least one coding agent: a Claude subscription (Pro, Max, Team or Enterprise) for Claude Code, a ChatGPT account for Codex, or a Google account for Gemini CLI. Sign in with the account itself rather than an API key, because `gc init` checks each agent's sign-in and refuses API keys.
- For the cloud box, the Google account or email address your instructor added to the cohort. For your own machine, macOS or Linux, or Windows with [WSL](https://learn.microsoft.com/en-us/windows/wsl/install).

## Context

There are two places to run your factory, and you pick one. Most people should take the cloud box. It arrives with the whole toolchain installed, so your laptop needs only `sfbox` and a browser. Your own machine works too, and its path installs by hand everything the box image already carries.

| | The cloud box (recommended) | Your own machine (alternative) |
| --- | --- | --- |
| Where the factory runs | A Linux box in Google Cloud | Your laptop |
| What you install on your laptop | `sfbox` | git, tmux, jq, `gh`, Go and a coding agent CLI, then `gc`, `bd` and `dolt` |
| Installed for you | `gc`, `bd`, `dolt`, `gh`, Claude Code, Codex and Gemini CLI, on the box | Nothing |
| Where you sign in to your agent and GitHub | The box's terminal | Your laptop |

On the cloud box path your laptop never needs `gc`, `bd`, `dolt`, `gh` or a copy of this repo, because everything after setup runs on the box. Whichever path you take, stay on it. From [W3](./W3-run-your-factory.md) on the steps are the same in either terminal, so this page is the only one where the two differ.

## The cloud box (recommended)

### 1. Get onto your box

Follow [`CLOUD_BOX_GUIDE.md`](../CLOUD_BOX_GUIDE.md), then come back here. The guide installs `sfbox` on your laptop and signs you in, then finds or creates your box, opens the box's terminal, and has you sign in to your coding agent and GitHub there. It needs only two things from your instructor: your account on the cohort's list, and your box's name if they made the box for you.

Everything below runs in the box's terminal. `sfbox ssh <box>` opens it from your laptop.

### 2. Check the box

**Copy and paste** (on the box)

```bash
gas-city-boot-status && echo "box ready"
command -v gc bd dolt gh
gh auth status
```

**Expected output** (the first five lines)

```text
box ready
/usr/local/bin/gc
/usr/local/bin/bd
/usr/local/bin/dolt
/usr/bin/gh
```

`gas-city-boot-status` prints nothing once the box has finished starting, so `box ready` means it has. The four paths are the image's own tools. After them, `gh auth status` should name the GitHub account you signed in with in the guide.

That's why this path has no `deps.sh` and no preflight script: the image already ships `gc`, `bd` and `dolt` at its own pinned versions, and those paths are them.

Run the check again whenever something on the box looks wrong, before you go looking at the factory. A box that's still starting, or a missing sign-in, gets mistaken for a broken factory all the time, and this tells them apart.

### 3. Set up your workspace on the box

**Copy and paste** (on the box)

```bash
mkdir -p ~/software-factory-intensive
cd ~/software-factory-intensive
export SFI_PATH="$(pwd)"
cat <<EOF >> ~/.bashrc
export SFI_PATH="$SFI_PATH"
EOF
git clone https://github.com/actual-software/sf-tutorial.git
```

That's the box ready for W3. Leave this terminal open, since W3 runs in it. If it closes or the connection drops, `sfbox ssh <box>` opens a new one, and `$SFI_PATH` comes back with it because the block saved it to `~/.bashrc`. Everything under `/home/ubuntu` stays on the box between connections.

## Your own machine (alternative)

This path installs by hand what the box image already carries, and every command on it runs in a terminal on your laptop.

### 1. Install the tools

You'll need git, tmux, curl and jq, which preflight checks for; the GitHub CLI, `gh`; Go, because `deps.sh` builds `gc` from source; and the CLI for at least one coding agent.

**Copy and paste** (macOS, with [Homebrew](https://brew.sh))

```bash
brew install git tmux jq gh go
```

On Linux, install git, tmux, curl and jq from your package manager (`sudo apt-get install -y git tmux curl jq` on Ubuntu or Debian). Then install `gh` from [GitHub's Linux instructions](https://github.com/cli/cli/blob/trunk/docs/install_linux.md), and Go from [go.dev/dl](https://go.dev/dl/), since your distribution's own Go package is often older than the build wants.

Install your coding agent from its own instructions: [Claude Code](https://docs.claude.com/en/docs/claude-code/setup), [Codex](https://github.com/openai/codex) or [Gemini CLI](https://github.com/google-gemini/gemini-cli).

### 2. Clone the tutorial

**Copy and paste**

```bash
cd $HOME && mkdir software-factory-intensive
cd software-factory-intensive
export SFI_PATH="$(pwd)"
git clone https://github.com/actual-software/sf-tutorial.git
cd sf-tutorial/bootstrap
```

### 3. Install gc, bd and dolt

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

Put `~/.local/bin` on your `PATH` for this terminal:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then add both variables to your shell rc, so a new terminal has them too:

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

### 4. Sign in to your coding agent

Start your agent's CLI once and sign in with your account: `claude` for Claude Code, `codex login` for Codex, or `gemini` for Gemini CLI. Each opens your browser for the sign-in. Then check it, with the line for each agent you signed in to:

**Copy and paste**

```bash
claude -p 'Reply with exactly: FACTORY_OK'
codex login status
gemini -p 'Reply with exactly: FACTORY_OK'
```

Claude and Gemini each answer `FACTORY_OK`. Codex prints `Logged in using ChatGPT`.

### 5. Sign in to GitHub

Your factory pushes to GitHub, so `gh` needs your account. `gh auth login`, picking HTTPS, is the shortest route: it opens a browser and authorizes the GitHub CLI against your whole account.

If you would rather not grant that, use a personal access token instead. Both kinds of token work, but they go in by different commands, and the two are not interchangeable.

**Classic token.** Create one under [Settings → Developer settings → Tokens (classic)](https://github.com/settings/tokens) with the `repo`, `read:org`, and `gist` scopes, then read it in from a file:

```bash
gh auth login --with-token < your-token-file
```

**Fine-grained token.** This is the kind that scopes to individual repositories, so it's the one to reach for when the point is keeping the rest of your account out of reach. Don't pass it to `--with-token`, because `gh` warns that its resource scoping causes confusing behaviour on commands that touch anything outside the token's repositories. Set the environment variable instead, and add the same line to your shell rc so a new terminal keeps it:

```bash
export GH_TOKEN=<your-token>
```

Grant it **Contents**, **Pull requests**, and **Administration**, all write, on the repository you will push the rig to. Administration is the one that is easy to miss: [the branch-protection appendix](../appendix/03-branch-protection.md) needs it to install branch protection, and that failure lands an hour into day one. A fine-grained token also has to name a repository that already exists, and the rig's repository is created in [W3](./W3-run-your-factory.md), so either create it now or come back and re-scope the token then.

**Either token needs one more command.** `--with-token` and `GH_TOKEN` both authenticate `gh` without telling `git` anything, so `git push` still fails with `could not read Username for 'https://github.com'`. The browser flow wires this up for you and the token routes do not:

```bash
gh auth setup-git
```

### 6. Run preflight

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

On a machine that has never used Dolt, the identity line is a `[warn]` instead, and the last line reads `PREFLIGHT: PASS (1 warning(s) — you are good to start)`. That's fine, because W3's first step sets the identity.

That's your machine ready for W3. Keep this terminal, or any new one, since your shell rc now carries `$SFI_PATH` and the `PATH` line.

## Troubleshooting

### On the cloud box

- **`gas-city-boot-status` names a boot step instead of finishing.** The box is still starting, and it's usually waiting for its data disk. Give it a minute and run the line again. If it says the box did not finish starting, take that to your instructor.
- **`command -v` prints fewer than four paths.** The image ships all four tools, so a missing one means the box hasn't finished starting. `sfbox status <box>` on your laptop shows its boot progress. If that reads `ready` and a tool is still missing, take it to your instructor.
- **`gh auth status` says you aren't logged in.** Run `gh auth login` on the box, the way the guide's [GitHub step](../CLOUD_BOX_GUIDE.md#step-6-sign-in-to-github-on-the-box) describes.
- **Anything about `sfbox` itself**, such as installing it, signing in, or `sfbox ssh` not connecting, is in the guide's [Troubleshooting](../CLOUD_BOX_GUIDE.md#troubleshooting) list.

### On your own machine

- **`PATH is missing ~/.local/bin`.** Run `export PATH="$HOME/.local/bin:$PATH"`, then add the same line to your shell rc so a new terminal keeps it.
- **`gh auth: not authenticated`.** Run `gh auth login` and pick HTTPS, or use a personal access token. [Sign in to GitHub](#5-sign-in-to-github) covers both token types and the `gh auth setup-git` step they need. You need this before the rig gets pushed, which happens in W3.
- **`bd: not found` right after `deps.sh` said it installed.** Almost always the `PATH` problem above. Confirm with `ls ~/.local/bin`.
- **A checksum mismatch during `deps.sh`.** A partial download. Re-run it; the script fetches to a temporary directory and cleans up after itself.
- **`gc: not found`, or a `gc` older than the pin.** Run `./deps.sh`, which builds `gc` at the pinned commit. The build needs Go on your `PATH`, so install it from [go.dev/dl](https://go.dev/dl/) first if the script says so. A `gc` *newer* than the pin passes: the check is a floor, not an exact match.
- **`dolt identity: … unset`.** A warning, not a failure. W3's first step sets it, so carry on.
- **`dolt` reports a different version than the pin.** That is a warning rather than a failure. It will probably work; mention it to an instructor so it can be ruled out if a later step misbehaves.

## What's next

You have a terminal ready, on the box or on your own machine. [W3](./W3-run-your-factory.md) builds the factory in it: a city, a rig on GitHub, the base factory pack, and your first bead moving through it while you watch.

« [previous: W1 Vocabulary and Concepts](./W1-vocabulary-and-concepts.md) | [next: W3 Run Your Factory](./W3-run-your-factory.md) »
