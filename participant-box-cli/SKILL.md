---
name: sfbox
description: Drive a Software Factory Intensive box over SSH. Saves credentials, deploys a factory pack, restarts the service, opens the dashboard, and reads box state. Use when the user mentions their workshop box, their Prod or Test box, deploying a pack, or a factory that will not start.
---

# Driving a workshop box with sfbox

The participant has one or more cloud boxes running Gas City. They've got an SSH key and no AWS account, so everything reaches the box over SSH. `sfbox` is the CLI that does it. Prefer it over hand-rolled `ssh` invocations, because it already knows where the city lives, it pins host keys, and it'll refuse a deploy that would break the box.

Run `sfbox --help` if you need the current command list.

## Before anything else

`sfbox preflight` answers the question that otherwise burns the most time: is the factory broken, or is the connection broken? Run it first whenever the user reports trouble. It checks SSH, then `gc`, then the service, stopping at the first thing that fails.

An inactive service has two expected causes, and preflight names which one it is. Read that line before you treat it as a fault.

On a box nobody's logged into yet, preflight reports the service as waiting on first-run login and names `sudo gas-city-login`. The unit is installed and enabled, but it's deliberately left stopped until a human finishes that one interactive step, because Claude Code's first run asks questions `gc` can't answer on an agent's behalf. Walk the user through the login instead of debugging a factory that was never asked to start.

On a box that ships without a city, preflight says there's no city on it yet. That box supplies the environment — toolchain, GitHub credential, agent CLIs — and the user builds the factory themselves as part of the tutorial. There is nothing to start and nothing to fix, so don't send them back through `gas-city-login`: they may well have already run it. Help them build a city if that's what they're trying to do.

If they haven't saved a box yet, they'll need three things from their instructor: the hostname, the private key file, and the host-key fingerprint.

```
sfbox save-credential --box alice-prod --host 203.0.113.10 \
  --key ~/Downloads/alice.pem --fingerprint SHA256:xxxxx --label prod
```

The fingerprint's required, deliberately. Pinning it at save time means the very first connection is authenticated instead of trusted on sight, and a rebuilt box then says it was replaced rather than looking like an attack. If it doesn't match, don't work around it. Tell the user to check with their instructor, and only reach for `--rotate` once the instructor's confirmed the box really was rebuilt — and note that it takes the *new* fingerprint too. `--rotate` alone won't get past a mismatch.

## Picking a box

Most participants run two boxes, so they're able to try a change on one and compare it against the other rather than mutating a single environment and hoping for the best. Commands act on the current box. Override that for one command with `--box <boxId>`.

```
sfbox box list          # what is saved, and which one is current
sfbox box use alice-test
sfbox gc --box alice-prod session list
```

When someone says "my test box" or "the other one", don't guess which id they meant. Check `sfbox box list`.

## Running a command on the box

```
sfbox exec <command> [args...]
sfbox gc <gc-args...>
```

`exec` runs anything on the box. `gc` runs a `gc` command inside the city, resolving the city path so the user doesn't have to know it. Both take `--box <boxId>`, and `gc` takes `--city-path <path>` for a box carrying more than one city.

Arguments reach the box exactly as typed, so quotes and spaces survive. That means metacharacters need an explicit shell: `sfbox exec bash -lc 'gc session list | wc -l'`, never `sfbox exec 'gc session list | wc -l'`. Options go before the command; anything after it is the command's. The remote exit status is what the user gets back.

There is no dry run, no snapshot and no rollback here. If the user is about to run something they can't undo, say so before they run it, because `sfbox` won't.

Rig scope is the case worth knowing. `gc import add` installs at city scope unless it's given `--rig <rig>`, and this is the only route a participant has to a rig-scoped install on their own box.

## Looking at a box

```
sfbox get-box
```

That'll report service state, sessions, and recent log. `journalctl` is the only log surface you've got on these boxes, so if the user starts hunting for a `supervisor.log` the way they might on a local city, redirect them early: there isn't one, and there never was.

## The dashboard

```
sfbox dashboard
```

This just opens an SSH tunnel and prints a `127.0.0.1` URL. The dashboard's embedded in the `gc` binary and served by the supervisor, so nothing needs starting on the box. It'll run in the foreground until Ctrl-C.

A busy port on the user's own laptop is the common snag here, and the command handles the two cases differently. If the default port is taken it moves to the next free one and says which, so read the port back off its output rather than assuming. If they passed `--port` and that port is taken, the command stops and names a free one to try. That's deliberate: ask them which port they want instead of choosing one for them.

Never suggest binding the API port publicly, or opening it up in the security group. Only `:22` belongs there, really. Binding it non-loopback also drops the API to read-only unless mutations are explicitly enabled, and it'll leave reads open to anyone who finds the address.

## Restarting

```
sfbox exec sudo systemctl restart gas-city.service
```

A restart takes 30 to 90 seconds, and the stop phase can sit there a while tearing sessions down. That's the service working, not hanging, so don't interrupt it or retry early. Nothing waits for the user here: check it came back with `sfbox exec systemctl is-active gas-city.service`, or watch the whole picture with `sfbox get-box`.

## Things to leave alone

`sfbox` owns `~/.gascity` and writes its own `ssh_config` in there. It never edits `~/.ssh/config`; it just asks the user to add one `Include` line. Keep that boundary. If native `ssh <boxId>` isn't working while `sfbox` commands are fine, that missing `Include` line is your answer.
