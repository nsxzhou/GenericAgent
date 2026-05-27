#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
    echo "This script only supports macOS."
    exit 1
fi

LABEL="com.genericagent.telegramapp"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
LOG_DIR="${HOME}/Library/Logs/GenericAgent"
LAUNCHD_LOG="${LOG_DIR}/telegramapp.launchd.log"
UPDATE_LOG="${LOG_DIR}/telegramapp.update.log"
UID_VALUE="$(id -u)"
TARGET="gui/${UID_VALUE}/${LABEL}"

print_kv() {
    printf '%-22s %s\n' "$1" "$2"
}

section() {
    printf '\n%s\n' "$1"
    printf '%s\n' "------------------------------------------------------------"
}

launchd_disabled_state() {
    local raw
    raw="$(launchctl print-disabled "gui/${UID_VALUE}" 2>/dev/null | awk -v label="${LABEL}" '$0 ~ label {print $0; exit}' || true)"
    if [[ -z "${raw}" ]]; then
        echo "unknown"
        return
    fi
    if [[ "${raw}" == *"false"* ]]; then
        echo "enabled"
    elif [[ "${raw}" == *"true"* ]]; then
        echo "disabled"
    else
        echo "${raw}"
    fi
}

launchd_pid() {
    launchctl print "${TARGET}" 2>/dev/null | awk -F'= ' '/pid = /{print $2; exit}' || true
}

launchd_state() {
    launchctl print "${TARGET}" 2>/dev/null | awk -F'= ' '/state = /{print $2; exit}' || true
}

section "telegram-launchagent 状态"
print_kv "Label" "${LABEL}"
print_kv "UID" "${UID_VALUE}"
print_kv "Target" "${TARGET}"
print_kv "Plist" "${PLIST_PATH}"
print_kv "Plist exists" "$([[ -f "${PLIST_PATH}" ]] && echo yes || echo no)"
print_kv "Launchd disabled" "$(launchd_disabled_state)"

if launchctl print "${TARGET}" >/dev/null 2>&1; then
    print_kv "Loaded" "yes"
    print_kv "State" "$(launchd_state)"
    pid="$(launchd_pid)"
    if [[ "${pid}" =~ ^[0-9]+$ ]]; then
        print_kv "PID" "${pid}"
        if ps -p "${pid}" >/dev/null 2>&1; then
            print_kv "Process alive" "yes"
            print_kv "Process cmd" "$(ps -p "${pid}" -o command= | sed 's/^ *//')"
        else
            print_kv "Process alive" "no"
        fi
    else
        print_kv "PID" "unknown"
    fi
else
    print_kv "Loaded" "no"
fi

section "运行文件"
print_kv "Launchd log" "${LAUNCHD_LOG}"
print_kv "Update log" "${UPDATE_LOG}"
print_kv "Launchd log exists" "$([[ -f "${LAUNCHD_LOG}" ]] && echo yes || echo no)"
print_kv "Update log exists" "$([[ -f "${UPDATE_LOG}" ]] && echo yes || echo no)"

section "最近日志"
if [[ -f "${LAUNCHD_LOG}" ]]; then
    tail -n 12 "${LAUNCHD_LOG}"
else
    echo "launchd log not found"
fi
