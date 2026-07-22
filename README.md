# push-notifications

Get iPhone & Apple Watch push notifications when **any coding agent** finishes a turn — Claude Code, GitHub Copilot CLI, Codex, aider, or any terminal-based agent. Uses [ntfy.sh](https://ntfy.sh) (free, open-source).

## Supported agents

| Agent | Integration | Method |
|-------|-------------|--------|
| Claude Code | ✅ Native | Stop hook in settings.json |
| GitHub Copilot CLI | ✅ | Shell wrapper function |
| OpenAI Codex CLI | ✅ | Shell wrapper function |
| aider | ✅ | Shell wrapper function |
| Any CLI agent | ✅ | Shell wrapper function |
| Cursor / VS Code | ⚠️ | Use built-in OS notifications |

## How it works

```
Agent finishes → notify.sh → curl ntfy.sh → iPhone → Apple Watch tap
```

A single `notify.sh` script is the engine. Each agent gets wired to call it — native hooks for agents that support them, shell wrappers for everything else. **One toggle** (`/push-notifications off`) disables all agents at once.

## Install

```bash
# Clone into your agents skills directory (shared by Claude Code & Copilot CLI)
git clone https://github.com/YOUR_USERNAME/push-notifications.git ~/.agents/skills/push-notifications

# Symlink into Claude Code skills directory
ln -sf ~/.agents/skills/push-notifications ~/.claude/skills/push-notifications
```

Then in any Claude Code session, type `/push-notifications`. It auto-detects your installed agents and configures each one.

Or with Copilot CLI:
```bash
copilot skill add ~/.agents/skills/push-notifications
```

## Requirements

- One of: Claude Code, GitHub Copilot CLI, Codex CLI, aider, or any terminal-based agent
- [ntfy](https://ntfy.sh/) app on iPhone (free, App Store)
- `qrencode` for QR code setup (auto-installed via brew on macOS)

## Commands

| Command | What it does |
|---------|-------------|
| `/push-notifications` | First run: full setup with QR code. After: show status. |
| `/push-notifications setup` | Force re-run setup |
| `/push-notifications off` | Disable push for all agents (chmod -x notify.sh) |
| `/push-notifications on` | Re-enable push for all agents (chmod +x notify.sh) |
| `/push-notifications test` | Send a test notification |
| `/push-notifications status` | Show topic, on/off state, configured agents |
| `/push-notifications sound` | Change the Mac alert sound |
| `/push-notifications add <agent>` | Configure a newly installed agent |

## Privacy

Your ntfy topic is a UUID — the only "authentication." Anyone who knows it can send you notifications, so treat it like a password. The topic is stored in `~/.push-notifications-topic`. All notification logic is local — `notify.sh` runs on your machine and only calls ntfy.sh to deliver.
