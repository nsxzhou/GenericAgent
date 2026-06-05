#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
    echo "This script only supports macOS."
    exit 1
fi

LABEL="com.genericagent.wechatapp"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
UID_VALUE="$(id -u)"
TARGET="gui/${UID_VALUE}/${LABEL}"

if [[ ! -f "${PLIST_PATH}" ]]; then
    echo "LaunchAgent plist not found: ${PLIST_PATH}"
    echo "Run: bash assets/install-wechat-launchagent.sh"
    exit 1
fi

launchctl enable "${TARGET}" >/dev/null 2>&1 || true

if launchctl print "${TARGET}" >/dev/null 2>&1; then
    launchctl kickstart -k "${TARGET}" >/dev/null 2>&1 || true
    echo "Started: ${LABEL}"
else
    launchctl bootstrap "gui/${UID_VALUE}" "${PLIST_PATH}"
    launchctl kickstart -k "${TARGET}" >/dev/null 2>&1 || true
    echo "Bootstrapped and started: ${LABEL}"
fi
