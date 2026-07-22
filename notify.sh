#!/usr/bin/env bash
# notify.sh — send a push notification via ntfy.sh
# Works on macOS, Linux, and Windows (Git Bash / WSL).
#
# Usage: notify.sh [label]
#   label defaults to "Agent" — set it to the agent name for context
#
# Topic is read from ~/.push-notifications-topic (set during setup).
# Toggle all notifications off: chmod -x notify.sh
# Toggle back on:              chmod +x notify.sh

set -euo pipefail

# ── OS detection ──────────────────────────────────────────────────────────
detect_os() {
  case "$(uname -s)" in
    Darwin)  echo "macos" ;;
    Linux)   echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *)       echo "unknown" ;;
  esac
}
OS="$(detect_os)"

# ── Topic ─────────────────────────────────────────────────────────────────
TOPIC_FILE="$HOME/.push-notifications-topic"
LABEL="${1:-Agent}"
DIR="${PWD##*/}"

if [[ ! -f "$TOPIC_FILE" ]]; then
  exit 0  # Silent — topic not set up yet
fi
TOPIC="$(cat "$TOPIC_FILE")"

# ── Push notification ─────────────────────────────────────────────────────
curl -s \
  -H "Priority: default" \
  -d "${LABEL} done — ${DIR}" \
  "ntfy.sh/${TOPIC}" \
  > /dev/null 2>&1 &

# ── Local sound ───────────────────────────────────────────────────────────
case "$OS" in
  macos)
    if command -v afplay &>/dev/null; then
      afplay /System/Library/Sounds/Glass.aiff &
    fi
    ;;
  linux)
    if command -v paplay &>/dev/null; then
      paplay /usr/share/sounds/freedesktop/stereo/complete.oga &
    elif command -v aplay &>/dev/null; then
      aplay /usr/share/sounds/alsa/Front_Center.wav 2>/dev/null &
    fi
    ;;
  windows)
    # PowerShell one-liner to play the Windows default notification sound
    powershell.exe -c "
      Add-Type -AssemblyName System.Speech
      (New-Object Media.SoundPlayer 'C:\Windows\Media\Windows Notify.wav').Play()
    " 2>/dev/null &
    ;;
esac

exit 0
