---
name: push-notifications
description: Set up, toggle, and test push notifications via ntfy.sh — get iPhone/Apple Watch alerts when any coding agent finishes
argument-hint: "[setup|toggle|on|off|test|status|sound]"
---

# Push Notifications for Coding Agents

Get iPhone & Apple Watch push notifications when any coding agent finishes a turn — Claude Code, GitHub Copilot, Codex, aider, or any CLI-based agent. Uses [ntfy.sh](https://ntfy.sh) (free, open-source).

## Architecture

```
Any agent finishes → notify.sh → curl ntfy.sh → iPhone notification → Apple Watch tap
```

A single `notify.sh` script is the engine. It reads the topic from `~/.push-notifications-topic` and fires the curl. Each agent is wired to call this script — the mechanism varies by agent but the script is the same.

**One toggle controls all agents:** `chmod -x notify.sh` (off) / `chmod +x notify.sh` (on).

## Agent integration strategies

| Agent | Method | Mechanism |
|-------|--------|-----------|
| **Claude Code** | Native Stop hook | `~/.claude/settings.json` → calls `notify.sh` |
| **GitHub Copilot CLI** | Shell wrapper | `copilot()` function in shell rc file wraps the CLI |
| **OpenAI Codex CLI** | Shell wrapper | `codex()` function in shell rc file wraps the CLI |
| **aider** | Shell wrapper | `aider()` function in shell rc file wraps the CLI |
| **Any CLI agent** | Shell wrapper | `agent-name()` function in shell rc file |
| **Cursor / VS Code** | OS notifications | Use the IDE's built-in notification settings; shell wrappers don't apply to GUI agents |
| **Windsurf** | OS notifications | Same as Cursor — GUI agent, use built-in settings |

## State detection (run first)

1. Check if `~/.push-notifications-topic` exists
2. Check `~/.claude/settings.json` for a Stop hook calling `notify.sh`
3. Check `~/.zshrc` and `~/.bashrc` for shell wrappers
4. Detect installed agents: `which claude`, `which copilot`, `which codex`, `which aider`

Determine mode:

| State | Action |
|-------|--------|
| No `~/.push-notifications-topic` | → **Setup mode** |
| Topic exists, no integrations configured | → **Partial setup** — configure integrations |
| Topic + at least one integration active | → **Manage mode** |

## Setup mode

### Step 1: Generate a topic

Run `uuidgen | tr '[:upper:]' '[:lower:]'` to generate a secret topic name. Write it to `~/.push-notifications-topic`.

### Step 2: Generate a QR code

The ntfy app supports deep-link subscription. Generate a QR code:

```bash
# Install qrencode if needed (instant on macOS)
brew install qrencode 2>/dev/null || true

# Generate QR in the terminal
qrencode -t ANSIUTF8 "https://ntfy.sh/$(cat ~/.push-notifications-topic)"
```

If `qrencode` can't be installed, fall back to Python:
```bash
python3 -c "
try:
    import qrcode
    qr = qrcode.QRCode()
    qr.add_data('https://ntfy.sh/' + open('$HOME/.push-notifications-topic').read().strip())
    qr.make(fit=True)
    qr.print_ascii(invert=True)
except ImportError:
    print('Run: brew install qrencode')
"
```

### Step 3: Present the setup card

Show the user:

```
╔══════════════════════════════════════════════════════╗
║      Push Notifications for Coding Agents           ║
╠══════════════════════════════════════════════════════╣
║                                                    ║
║   Topic: <uuid>                                    ║
║                                                    ║
║   [QR CODE DISPLAYED ABOVE]                        ║
║   ↑ Scan with iPhone camera ↑                      ║
║                                                    ║
║   1. Install ntfy from the App Store               ║
║   2. Open ntfy, tap + to subscribe                 ║
║   3. Scan the QR code (or paste the topic)         ║
║   4. I'll detect your agents and configure each    ║
║                                                    ║
╚══════════════════════════════════════════════════════╝
```

### Step 4: Detect agents and configure

Run `which claude`, `which copilot`, `which codex`, `which aider` to detect installed agents.

For each detected agent, configure the appropriate integration:

#### Claude Code (native Stop hook)

Edit `~/.claude/settings.json` — add a Stop hook that calls `notify.sh`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.agents/skills/push-notifications/notify.sh 'Claude Code'"
          }
        ]
      }
    ]
  }
}
```

Merge with any existing settings keys (`env`, `permissions`, `theme`, etc.). If `hooks.Stop` already exists, add the notify entry to the array — never remove existing hooks.

If Claude Code is running, tell the user to run `/hooks` to activate.

#### GitHub Copilot CLI (shell wrapper)

Add to `~/.zshrc` (or `~/.bashrc`):

```bash
# Push notification wrapper — calls notify.sh when Copilot finishes
copilot() {
  command copilot "$@"
  ~/.agents/skills/push-notifications/notify.sh "Copilot"
}
```

If a `copilot` alias/function already exists, warn the user and show both versions — let them choose.

#### OpenAI Codex CLI (shell wrapper)

If `codex` is detected:

```bash
codex() {
  command codex "$@"
  ~/.agents/skills/push-notifications/notify.sh "Codex"
}
```

#### aider (shell wrapper)

If `aider` is detected:

```bash
aider() {
  command aider "$@"
  ~/.agents/skills/push-notifications/notify.sh "Aider"
}
```

#### Any other CLI agent

Offer the same pattern — a shell function wrapping the binary:

```bash
agent-name() {
  command agent-name "$@"
  ~/.agents/skills/push-notifications/notify.sh "Agent Name"
}
```

#### Cursor / Windsurf / IDE agents

These are GUI apps with no terminal lifecycle hook to intercept. Tell the user:
- **Cursor**: Settings → Features → enable "Show notifications"
- **Copilot in VS Code**: Already has built-in notifications in the Copilot Chat panel
- IDE notifications can't be mirrored to iPhone via this mechanism — they stay on desktop

### Step 5: Confirm and test

After configuring all agents, tell the user:
- Which agents were configured and how (hook vs wrapper)
- "The next time you use `<agent>`, you'll get a push notification when it finishes"
- "To test now: `/push-notifications test`"
- "To toggle all push notifications off: `/push-notifications off` (disables notify.sh for all agents at once)"

If Claude Code was configured via Stop hook: "This very response will trigger your first notification — the Stop hook fires now."

## Manage mode

### Toggle on/off

**Off** (`/push-notifications off`): `chmod -x ~/.agents/skills/push-notifications/notify.sh`
This makes the script a no-op for ALL agents simultaneously. Hook commands and shell wrappers still run, but `notify.sh` exits silently.

**On** (`/push-notifications on`): `chmod +x ~/.agents/skills/push-notifications/notify.sh`

### Test

Run directly:
```bash
~/.agents/skills/push-notifications/notify.sh "Test"
```

### Status

Read `~/.push-notifications-topic` and `~/.claude/settings.json`. Report:
- Topic (masked: first 8 chars + `...`)
- Whether notify.sh is executable (push enabled or disabled)
- Which agents are configured:
  - Claude Code: hook present in settings.json? (yes/no)
  - Copilot: wrapper in shell rc? (yes/no)
  - Codex: wrapper in shell rc? (yes/no)
  - aider: wrapper in shell rc? (yes/no)
- Local sound: which sound is configured

### Add a new agent

If the user says "add copilot" / "add codex" / "add aider":
- Detect if the agent binary exists
- Add the appropriate shell wrapper or hook
- Tell the user to `source ~/.zshrc` (or restart their shell) for wrapper functions

### Remove an agent

If the user says "remove copilot" / "remove codex" / etc.:
- For shell wrappers: remove the function from `~/.zshrc` / `~/.bashrc`
- For Claude Code stop hook: remove only the hook entry calling `notify.sh` (preserve other stop hooks)

### Sound

Offer to change the local alert sound (macOS only):

```
1. Glass.aiff     (default, gentle)
2. Ping.aiff      (subtle)
3. Pop.aiff       (sharp)
4. Purr.aiff      (warm)
5. Hero.aiff      (triumphant)
6. Basso.aiff     (deep)
7. Blow.aiff      
8. Funk.aiff      
9. Morse.aiff     
10. Submarine.aiff
11. Tink.aiff     
```

Edit `notify.sh` to change the sound in the `afplay` line. Linux: change `paplay` path.

## Customization (offer when relevant)

### Priority levels

ntfy supports: `default` (respects DnD), `high` (bypasses DnD), `urgent` (bypasses DnD + repeated alerts). Edit `notify.sh` to change `-H "Priority: default"` to `high` or `urgent`.

### Self-hosted ntfy

Replace `ntfy.sh` with the user's server URL in `notify.sh`. A single edit — all agents use the same script.

### Custom messages

Edit the `-d` body in `notify.sh`. Variables: `$DIR` (current directory name), `$1` (agent label).

### Apple Watch haptic-only (no sound on phone)

Add `-H "X-Android-Custom-Ringer: silent"` to the curl command. Or in the ntfy app, set the topic's notification sound to "None."

## Edge cases

- **settings.json has syntax errors**: Validate JSON before editing. Use `python3 -m json.tool` to check.
- **Shell wrapper conflicts**: If a function/alias already exists for the agent, show both versions and let the user decide. Never overwrite without asking.
- **User runs agent in a different terminal**: Shell wrappers only work when the agent is invoked by name. If the user calls `/usr/local/bin/claude` directly, the wrapper doesn't fire. The Claude Code Stop hook (native integration) is immune to this — it fires regardless of how Claude was launched.
- **IDE-based agents**: Can't be intercepted from the terminal. Don't promise what can't be delivered — tell the user to use the IDE's built-in notification settings.
- **Multiple shell rc files**: Check both `~/.zshrc` and `~/.bashrc`. Use the one matching `$SHELL`. If `$SHELL` is zsh, prefer `.zshrc`; if bash, `.bashrc`.
- **notify.sh permissions during toggle**: `chmod -x` is the atomic off switch. Verify it worked by checking `ls -l`. If chmod fails (e.g., filesystem issue), fall back to commenting out the curl line in notify.sh.
