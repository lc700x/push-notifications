#!/usr/bin/env bash
# notify.sh — send a push notification via ntfy.sh
# Called by coding agent hooks and shell wrappers.
#
# Usage: notify.sh [label]
#   label defaults to "Agent" — set it to the agent name for context
#
# Topic is read from ~/.push-notifications-topic (set during setup).
# Toggle notifications off by making this file a no-op:
#   chmod -x ~/.agents/skills/push-notifications/notify.sh
# Toggle back on: chmod +x

set -euo pipefail

TOPIC_FILE="$HOME/.push-notifications-topic"
LABEL="${1:-Agent}"
DIR="$(basename "${PWD:-$HOME}")"

if [[ ! -f "$TOPIC_FILE" ]]; then
  # Silent fail — topic not set up yet
  exit 0
fi

TOPIC="$(cat "$TOPIC_FILE")"

# Suppress all output — this runs in hook context where stdout/stderr are noise
curl -s \
  -H "Priority: default" \
  -d "${LABEL} done — ${DIR}" \
  "ntfy.sh/${TOPIC}" \
  > /dev/null 2>&1 &

# Local sound (macOS only — harmless no-op on Linux if afplay doesn't exist)
if command -v afplay &>/dev/null; then
  afplay /System/Library/Sounds/Glass.aiff &
elif command -v paplay &>/dev/null; then
  paplay /usr/share/sounds/freedesktop/stereo/complete.oga &
fi

exit 0
