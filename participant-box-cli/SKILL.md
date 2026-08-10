---
name: sfbox
description: Drive a Software Factory Intensive box over SSH. Saves credentials, deploys a factory pack, restarts the service, opens the dashboard, and reads box state. Use when the user mentions their workshop box, their Prod or Test box, deploying a pack, or a factory that will not start.
---

# Driving a workshop box with sfbox

The participant has one or more cloud boxes running Gas City. They've got an SSH key and no AWS account, so everything reaches the box over SSH. `sfbox` is the CLI that does it. Prefer it over hand-rolled `ssh` invocations, because it already knows where the city lives, it pins host keys, and it'll refuse a deploy that would break the box.

Run `sfbox --help` if you need the current command list.

## Before anything else

`sfbox preflight` answers the question that otherwise burns the most time: is the factory broken, or is the connection broken? Run it first whenever the user reports trouble. It checks SSH, then `gc`, then the service, stopping at the first thing that fails.

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
sfbox deploy-factory <url> --box alice-prod
```

When someone says "my test box" or "the other one", don't guess which id they meant. Check `sfbox box list`.

## Deploying a factory

```
sfbox deploy-factory https://github.com/<org>/<repo>/tree/<ref>/<subdir>
```

The pack becomes the top-level factory, which means the imports already sitting on the box get removed, and that's worth spelling out before the user agrees to it, because a workshop box usually has a factory on it they'd rather not lose by accident. `sfbox` prints the plan and asks before touching anything, so read that plan back to the user if they're unsure. Gas City's own `core` and `bd` imports are never removed, though.

The ref gets resolved to a commit for you. Pass `--version sha:<commit>` when the user's after a particular one.

## When a deploy is refused for size

This is the failure that's worth recognising on sight, because the error the platform hands you is pretty misleading.

Before restarting, `sfbox` renders every agent prompt on the box and measures it. A rendered prompt goes to the agent as a single argument, and Linux caps one argument at 131,072 bytes including its terminator. A pack over that limit can't start. Ever. It isn't flaky, and it isn't a timing problem either.

If `sfbox` refuses, the box was left alone. The import's rolled back and the service was never restarted, so whatever factory the user had is still running happily. Do say that plainly, since the natural assumption is that a refused deploy broke something.

The fix is shrinking the *rendered* prompt, not just the template. Much of the size usually arrives at render time, so cutting prose from the template tends to move the number far less than you'd expect. Measure on the box as you iterate:

```
sfbox start-session
cd <city> && gc prime <agent> --strict | wc -c
```

Without `--strict`, `gc prime` quietly falls back to a short default prompt for any agent it can't resolve, and an oversized pack then measures small. Always pass it.

Sometimes the user hits this outside `sfbox` entirely: a factory that won't start, with a log line about a session dying during startup. Check prompt size first. That message points at the session layer, but really the cause is the argument limit.

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

Never suggest binding the API port publicly, or opening it up in the security group. Only `:22` belongs there, really. Binding it non-loopback also drops the API to read-only unless mutations are explicitly enabled, and it'll leave reads open to anyone who finds the address.

## Restarting

```
sfbox restart-factory
```

A restart takes 30 to 90 seconds, and the stop phase can sit there a while tearing sessions down. That's the service working, not hanging. `sfbox` waits and reports when it's back, so don't interrupt it or retry early.

## Things to leave alone

`sfbox` owns `~/.gascity` and writes its own `ssh_config` in there. It never edits `~/.ssh/config`; it just asks the user to add one `Include` line. Keep that boundary. If native `ssh <boxId>` isn't working while `sfbox` commands are fine, that missing `Include` line is your answer.
