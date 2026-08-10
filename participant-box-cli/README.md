# sfbox — drive your workshop boxes from your laptop

You'll get two cloud boxes for the intensive, Prod and Test. That's so you can try a change on one and compare it against the other, rather than mutating a single environment and hoping for the best. Your instructor owns the AWS account and hands you an SSH key. Everything after that, you do from here.

`sfbox` is one bash script. It saves your box credentials, deploys a factory pack, restarts the service, tunnels the dashboard to your browser, and tells you what the box is up to.

## Install

```bash
git clone https://github.com/actual-software/sf-tutorial.git
export PATH="$PWD/sf-tutorial/participant-box-cli:$PATH"
sfbox --help
```

Put that `PATH` line in your shell profile to make it stick. There's nothing to build, and nothing to install past what you've already got: bash, ssh, and curl.

The skill sits next to it, and it's optional. If you'd like your coding agent to drive `sfbox` for you, copy it in:

```bash
mkdir -p ~/.claude/skills/sfbox
cp sf-tutorial/participant-box-cli/SKILL.md ~/.claude/skills/sfbox/SKILL.md
```

It's plain markdown with no harness-specific syntax, so Codex CLI, Gemini CLI, or anything else that reads free-form skill files will happily take it too.

## Save your first box

Your instructor gives you three things: a hostname, a private key, and a host-key fingerprint.

```bash
sfbox save-credential \
  --box alice-prod \
  --host 203.0.113.10 \
  --key ~/Downloads/alice.pem \
  --fingerprint SHA256:AbCdEf... \
  --label prod
```

That fingerprint isn't optional, and the reason's worth knowing. `sfbox` fetches the key your box is actually offering and checks it against the one you were handed, so your very first connection is authenticated instead of trusted on sight. Later, when your instructor rebuilds a box, you'll just get a clear "this box was replaced" rather than a scary warning that reads like an attack. For a genuine rebuild, get the new fingerprint from your instructor and pass that, adding `--rotate` to say the change was expected. `--rotate` on its own won't get you past a mismatch, and that's deliberate.

Run it again for your second box. Then look at both:

```bash
sfbox box list
```

### The one manual step

`sfbox` writes its own SSH config and never touches yours. To get plain `ssh`, `scp`, `rsync` and port-forwards working with your box ids, add one line at the **top** of `~/.ssh/config`:

```
Include ~/.gascity/ssh_config
```

`sfbox` itself works fine without it. The Include is what makes everything *else* work, and it means the habits you're building this week will carry over to real hosts afterwards.

## Everyday commands

Commands act on your current box. Switch it with `sfbox box use <boxId>`, or override just the one command using `--box <boxId>`.

| Command | What it does |
|---|---|
| `sfbox preflight` | Checks ssh, then `gc`, then the service |
| `sfbox get-box` | Service state, running sessions, recent log |
| `sfbox start-session` | Opens a shell on the box |
| `sfbox deploy-factory <url>` | Makes a pack the top-level factory and restarts |
| `sfbox restart-factory` | Restarts the Gas City service |
| `sfbox dashboard` | Tunnels the dashboard to `http://127.0.0.1:8372` |

When something's wrong, start with `sfbox preflight`. It'll tell "my factory is broken" apart from "my ssh is broken", and honestly those two get mistaken for each other constantly.

## Deploying a factory

Point it at any public GitHub path:

```bash
sfbox deploy-factory https://github.com/actual-software/actual-factory-demo/tree/main/factory
```

Your pack becomes the top-level factory, so whatever imports you've already got on the box are replaced, with the single exception of Gas City's own `core` and `bd` imports, which get left alone because pulling those would break the city rather than swap the factory. You'll see the whole plan first. Nothing changes until you confirm it.

```mermaid
flowchart TD
    A[resolve the ref to a commit] --> B[gc import add]
    B --> C[gc import remove existing]
    C --> D[gc import install]
    D --> E{every rendered agent prompt<br/>under 131,072 bytes?}
    E -- yes --> F[restart gas-city.service]
    E -- no --> G[roll the imports back]
    F --> H[factory running the new pack]
    G --> I[refused, old factory still running]
```

That size check is the step worth understanding, and it's the reason the restart is deliberately the very last thing to happen: everything before it can be undone, so the one irreversible step waits until the check has already passed.

## Why a deploy can be refused

Gas City hands an agent's whole rendered prompt over as a single command-line argument. Linux caps one argument at 131,072 bytes, counting the terminator. So a pack whose rendered prompt crosses that line can't start. Not sometimes. Never.

Here's why the guardrail earns its keep. The platform reports this failure as a session dying during startup, which points straight at the session layer and sends you hunting around in completely the wrong place, when what's really happening is just the kernel refusing to exec.

So `sfbox` renders every agent on the box and measures it before restarting anything. If a prompt's too big, the deploy stops, the import gets rolled back, and **your box keeps running the factory it already had**. A refused deploy costs you nothing.

Fixing an oversized pack means shrinking the prompt as *rendered*, not as written. Quite a lot of the size usually shows up at render time, so trimming prose out of the template often barely moves the number at all. Measure it directly as you iterate:

```bash
sfbox start-session
cd <your-city> && gc prime <agent> --strict | wc -c
```

Do pass `--strict`. Without it, `gc prime` quietly falls back to a short default prompt for any agent it can't resolve, so an oversized pack measures small and looks perfectly healthy.

## The dashboard

```bash
sfbox dashboard
```

The dashboard's built into the `gc` binary and served by the supervisor, so there's nothing to deploy or start. `sfbox` forwards it over SSH and prints you a local URL. Leave the command running; Ctrl-C closes the tunnel.

Tunnelling is the whole point. Your security group opens `:22` and nothing else, and because you're reaching the dashboard same-origin through the tunnel, it stays fully read-write. Bind it to a public interface instead and you'd leave reads open to anyone who found the address, plus the API would drop to read-only unless you'd explicitly switched mutations on.

## Where your state lives

```
~/.gascity/
  boxes.toml          your boxes, and which one is current
  keys/<boxId>.pem    private keys, mode 0600
  known_hosts         host keys, pinned when you saved each box
  ssh_config          generated; the file you Include
```

`sfbox` owns that directory. Drop a box with `sfbox box forget <boxId>`, which clears the local credential and leaves the box itself completely untouched.

## Running the tests

```bash
./tests/run-tests.sh
```

These cover what runs on your laptop: local state, URL parsing, SSH config generation, and the decision half of the size guardrail. Anything that needs a live box isn't covered here.
