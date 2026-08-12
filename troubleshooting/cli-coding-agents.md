# Troubleshooting CLI coding agents

Issues with the coding agents that front the factory — Claude Code, Codex, Cursor CLI, and any other agent that loads the curriculum's skills / slash commands.

## Contents

**Multi-account setup with [`aisw`](https://burakdede.github.io/aisw/)** — for when a coding agent exhausts its token quota mid-session and you want to fail over to a second account on the same CLI:

- [Issue: Coding agent hits a quota / rate-limit error mid-session](#issue-coding-agent-hits-a-quota--rate-limit-error-mid-session)
- [Issue: Ran `aisw use` but the CLI still uses the old account](#issue-ran-aisw-use-but-the-cli-still-uses-the-old-account)
- [Issue: Not sure which account is currently active](#issue-not-sure-which-account-is-currently-active)
- [Issue: `aisw status` shows a coding agent as "not installed" even though it works](#issue-aisw-status-shows-a-coding-agent-as-not-installed-even-though-it-works)
- [Issue: `aisw use gemini … --state-mode shared` fails](#issue-aisw-use-gemini----state-mode-shared-fails)

---

## Issue: Coding agent hits a quota / rate-limit error mid-session

**Symptom:** Claude Code, Codex CLI, or Gemini CLI returns a quota / rate-limit / "out of tokens" error, either in an interactive session or inside a running factory agent. Work stalls until the subscription window resets.

**Cause:** The currently-active account has burned through its subscription quota (e.g. a Claude Max five-hour window).

### Recommended fix: switch the CLI to API billing

API (pay-as-you-go) billing is separate from your subscription quota, so a subscription that is rate-limited or exhausted can still keep working by authenticating with an API key from the same provider. This is the fastest unblock for a factory mid-run: you keep the same account, just change how usage is metered.

1. **Claude Code:**
   ```bash
   export ANTHROPIC_API_KEY=sk-ant-...     # from console.anthropic.com
   ```
   Or, inside the Claude Code session, run `/login` and choose "API key" when prompted. Usage will now bill against your Anthropic Console credits instead of the Max quota. ([docs](https://docs.claude.com/en/docs/claude-code/setup#api-key-authentication))
2. **Codex CLI:**
   ```bash
   export OPENAI_API_KEY=sk-...            # from platform.openai.com
   ```
   Or run `codex login` and pick "API key" over the ChatGPT subscription path.
3. **Gemini CLI:**
   ```bash
   export GEMINI_API_KEY=...               # from aistudio.google.com/app/apikey
   ```

Restart the coding agent (or `gc restart` for factory agents) so the new credentials are read at startup. Set the env var in your shell config if you want the switch to persist.

### Alternative: swap to a second account with `aisw`

If you have a second *subscription* account (e.g. a personal and a work Claude Max), [`aisw`](https://burakdede.github.io/aisw/) can fail over to it without touching API keys. `aisw` is a standalone account manager for Claude Code, Codex CLI, and Gemini CLI — install via `brew install aisw`, the shell installer, or `cargo install aisw`. It stores named profiles under `~/.aisw/` and swaps a CLI's active credentials on demand. See [Medium - Setting Up Multiple Claude Code Accounts on Your Local Machine](https://medium.com/@buwanekasumanasekara/setting-up-multiple-claude-code-accounts-on-your-local-machine-f8769a36d1b1) for more information.

One-time setup for a second Claude Max account:

1. Log into the first account with `claude` and let it write its credentials. Snapshot them:
   ```bash
   aisw save claude personal
   ```
2. Log out of Claude Code, log into the second account, and snapshot that one too:
   ```bash
   aisw save claude work
   ```
3. Install the shell hook so `aisw use` updates your current shell:
   ```bash
   aisw shell-hook
   source ~/.zshrc                 # or ~/.bashrc / ~/.config/fish/config.fish
   ```

Fail over during a quota hit:

1. See which account is active and which others are available:
   ```bash
   aisw status
   aisw list
   ```
2. Switch to a profile that still has headroom:
   ```bash
   aisw use claude <profile>      # or: aisw use codex <profile> / aisw use gemini <profile>
   ```
3. Restart the coding agent so it picks up the new credentials — exit and relaunch Claude Code / Codex / Gemini (or `gc restart` for factory agents).

Reach for `aisw` when you prefer subscription-only usage (predictable cost) and already have a spare account; reach for API billing when you don't, or when you only need to unblock for a few minutes.

---

## Issue: Ran `aisw use` but the CLI still uses the old account

**Symptom:** You ran `aisw use claude <profile>` (or similar), but Claude Code still reports the previous account, still hits the same rate limit, or your quota dashboard shows no change.

**Cause:** One of:

- The aisw shell hook isn't sourced, so the new env vars never landed in your shell.
- The coding agent was already running and cached credentials at startup — a switch doesn't retroactively change a live session.

**Fix:**

1. Confirm the shell hook is loaded:
   ```bash
   echo "$AISW_SHELL_HOOK"
   ```
   If it prints empty, source your shell config (`source ~/.zshrc`, `source ~/.bashrc`, or `source ~/.config/fish/config.fish`). Re-install the hook if missing:
   ```bash
   aisw shell-hook
   ```
2. Fully exit the coding agent and relaunch it — a reload / `/clear` inside the same process is not enough. For factory agents, `gc restart` so each agent process is replaced.
3. Re-run `aisw status` from the new shell to confirm the switch stuck before relaunching the CLI.

---

## Issue: Not sure which account is currently active

**Symptom:** You have multiple profiles configured and want to know which one the next `claude` / `codex` / `gemini` invocation will use.

**Fix:**

```bash
aisw status            # human-readable
aisw status --json     # scriptable — useful in CI or shell prompts
aisw list              # all configured profiles per tool
```

If you want this visible at a glance, add `aisw status` output to your shell prompt — there's a one-liner in the [aisw docs](https://burakdede.github.io/aisw/).

---

## Issue: `aisw status` shows a coding agent as "not installed" even though it works

**Symptom:** `claude` / `codex` / `gemini` runs fine on your PATH, but `aisw status` reports it as missing and `aisw use <tool> …` refuses to switch profiles.

**Cause:** The binary isn't on `aisw`'s resolved `PATH`, or your shell's command-hash cache is stale.

**Fix:**

1. Confirm the CLI is reachable:
   ```bash
   which claude     # or: which codex / which gemini
   ```
2. Refresh your shell's command cache:
   ```bash
   hash -r          # bash/zsh
   rehash           # zsh (alternative)
   ```
3. Run the built-in diagnostic:
   ```bash
   aisw doctor
   ```
4. If a tool was installed to a non-standard location (e.g. a `~/bin` not in the default `PATH`), add that directory to `PATH` in your shell config before the aisw hook runs, then restart the shell.

---

## Issue: `aisw use gemini … --state-mode shared` fails

**Symptom:** Switching a Gemini profile with `--state-mode shared` errors out.

**Cause:** Gemini doesn't support configurable shared state mode in `aisw`; the flag is only valid for Claude and Codex.

**Fix:** Drop the `--state-mode` flag when switching Gemini profiles:

```bash
aisw use gemini <profile>
```
