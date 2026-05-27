#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
    echo "This script only supports macOS."
    exit 1
fi

LABEL="com.genericagent.telegramapp"
START_COMMAND="telegram-launchagent-start"
STOP_COMMAND="telegram-launchagent-stop"
STATUS_COMMAND="telegram-launchagent-status"
UPDATE_COMMAND="telegram-launchagent-update"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
COMMAND_LINKS=(
    "/opt/homebrew/bin/${START_COMMAND}"
    "/opt/homebrew/bin/${STOP_COMMAND}"
    "/opt/homebrew/bin/${STATUS_COMMAND}"
    "/opt/homebrew/bin/${UPDATE_COMMAND}"
    "/usr/local/bin/${START_COMMAND}"
    "/usr/local/bin/${STOP_COMMAND}"
    "/usr/local/bin/${STATUS_COMMAND}"
    "/usr/local/bin/${UPDATE_COMMAND}"
    "${HOME}/.local/bin/${START_COMMAND}"
    "${HOME}/.local/bin/${STOP_COMMAND}"
    "${HOME}/.local/bin/${STATUS_COMMAND}"
    "${HOME}/.local/bin/${UPDATE_COMMAND}"
)
UID_VALUE="$(id -u)"

launchctl bootout "gui/${UID_VALUE}" "${PLIST_PATH}" >/dev/null 2>&1 || true
launchctl disable "gui/${UID_VALUE}/${LABEL}" >/dev/null 2>&1 || true
rm -f "${PLIST_PATH}"
for link in "${COMMAND_LINKS[@]}"; do
    rm -f "${link}"
done

echo "Uninstalled: ${LABEL}"
