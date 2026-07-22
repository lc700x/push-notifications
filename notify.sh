#!/usr/bin/env bash
# notify.sh — send a push notification via ntfy.sh
# Works on macOS, Linux, and Windows (Git Bash / WSL).
#
# Usage: notify.sh [label] [--details]
#   label      Agent name for context (default: "Agent")
#   --details  Include git diff summary in the notification body
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

# ── Parse args ────────────────────────────────────────────────────────────
LABEL=""
DETAILS=false
for arg in "$@"; do
  case "$arg" in
    --details|-d) DETAILS=true ;;
    *) LABEL="$arg" ;;
  esac
done
LABEL="${LABEL:-Agent}"

# ── Topic ─────────────────────────────────────────────────────────────────
TOPIC_FILE="$HOME/.push-notifications-topic"
DIR="${PWD##*/}"

if [[ ! -f "$TOPIC_FILE" ]]; then
  exit 0  # Silent — topic not set up yet
fi
TOPIC="$(cat "$TOPIC_FILE")"

# ── Trailing-edge debounce (--details mode only) ──────────────────────────
# In --details mode, Claude fires Stop hooks on every internal turn
# (tool calls, mid-task responses), not just when truly done.
# This debounce ensures only the LAST event in a burst fires a push.
DEBOUNCE_SEC=7
MARKER_FILE="/tmp/push-notify-marker-$$"

# ── Build notification body ───────────────────────────────────────────────
SKIP_PUSH=false

if $DETAILS && command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null 2>&1; then
  CHANGED=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
  DIFF_SUMMARY=$(git diff --stat -- . 2>/dev/null | tail -1 || echo "")
  STAGED_SUMMARY=$(git diff --stat --cached -- . 2>/dev/null | tail -1 || echo "")

  if [[ "$CHANGED" -gt 0 ]]; then
    BODY="${LABEL} done — ${DIR} | ${CHANGED} file(s) changed"
    if [[ -n "$DIFF_SUMMARY" ]]; then
      BODY+=" (${DIFF_SUMMARY})"
    fi
    if [[ -n "$STAGED_SUMMARY" ]]; then
      BODY+=" [staged: ${STAGED_SUMMARY}]"
    fi
  else
    # No file changes — skip the push entirely.
    SKIP_PUSH=true
  fi
else
  BODY="${LABEL} done — ${DIR}"
fi

# ── Push notification (debounced in --details mode) ────────────────────────
if ! $SKIP_PUSH; then
  if $DETAILS; then
    # Trailing-edge debounce: only the last event in a burst fires.
    # We touch a marker file, sleep, then check if we're still the newest.
    # If a newer notify.sh ran during the sleep, it suppresses us.
    touch "$MARKER_FILE"
    (
      sleep "$DEBOUNCE_SEC"
      NEWEST=$(ls -t /tmp/push-notify-marker-* 2>/dev/null | head -1)
      if [[ "$NEWEST" == "$MARKER_FILE" ]]; then
        # We're the last turn in the burst — fire the notification
        curl -s \
          -H "Priority: default" \
          -H "Title: ${LABEL} done" \
          -d "${BODY}" \
          "ntfy.sh/${TOPIC}" \
          > /dev/null 2>&1
      fi
      rm -f "$MARKER_FILE"
    ) &
  else
    # Non-details mode: fire immediately (backward compatible)
    curl -s \
      -H "Priority: default" \
      -H "Title: ${LABEL} done" \
      -d "${BODY}" \
      "ntfy.sh/${TOPIC}" \
      > /dev/null 2>&1 &
  fi
fi

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
    powershell.exe -c "
      Add-Type -AssemblyName System.Speech
      (New-Object Media.SoundPlayer 'C:\Windows\Media\Windows Notify.wav').Play()
    " 2>/dev/null &
    ;;
esac

exit 0
