#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
    echo "This script only supports macOS."
    exit 1
fi

LABEL="com.genericagent.telegramapp"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
UID_VALUE="$(id -u)"

launchctl bootout "gui/${UID_VALUE}" "${PLIST_PATH}" >/dev/null 2>&1 || true
launchctl disable "gui/${UID_VALUE}/${LABEL}" >/dev/null 2>&1 || true

echo "Stopped and disabled: ${LABEL}"
