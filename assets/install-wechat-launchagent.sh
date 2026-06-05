#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
    echo "This installer only supports macOS."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LABEL="com.genericagent.wechatapp"
GA_COMMAND="ga"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
LOG_DIR="${HOME}/Library/Logs/GenericAgent"
WRAPPER_SCRIPT="${PROJECT_ROOT}/assets/wechat_launchd.sh"
GA_SCRIPT="${PROJECT_ROOT}/assets/ga.sh"
START_SCRIPT="${PROJECT_ROOT}/assets/start-wechat-launchagent.sh"
STOP_SCRIPT="${PROJECT_ROOT}/assets/stop-wechat-launchagent.sh"
STATUS_SCRIPT="${PROJECT_ROOT}/assets/status-wechat-launchagent.sh"
UID_VALUE="$(id -u)"

if [[ ! -f "${PROJECT_ROOT}/frontends/wechatapp.py" ]]; then
    echo "frontends/wechatapp.py not found at ${PROJECT_ROOT}"
    exit 1
fi

if [[ ! -f "${WRAPPER_SCRIPT}" ]]; then
    echo "wrapper script not found at ${WRAPPER_SCRIPT}"
    exit 1
fi

if [[ ! -f "${GA_SCRIPT}" ]]; then
    echo "ga script not found at ${GA_SCRIPT}"
    exit 1
fi

if [[ ! -f "${START_SCRIPT}" ]]; then
    echo "start script not found at ${START_SCRIPT}"
    exit 1
fi

if [[ ! -f "${STOP_SCRIPT}" ]]; then
    echo "stop script not found at ${STOP_SCRIPT}"
    exit 1
fi

if [[ ! -f "${STATUS_SCRIPT}" ]]; then
    echo "status script not found at ${STATUS_SCRIPT}"
    exit 1
fi

install_command() {
    local command_name="$1"
    local target_script="$2"
    local install_dir=""

    for dir in "/opt/homebrew/bin" "/usr/local/bin"; do
        if [[ -d "${dir}" && -w "${dir}" ]]; then
            install_dir="${dir}"
            break
        fi
    done

    if [[ -z "${install_dir}" ]]; then
        install_dir="${HOME}/.local/bin"
        mkdir -p "${install_dir}"
    fi

    ln -sfn "${target_script}" "${install_dir}/${command_name}"
    chmod +x "${install_dir}/${command_name}"
    echo "Shortcut installed: ${install_dir}/${command_name}"

    if [[ "${install_dir}" == "${HOME}/.local/bin" && ":${PATH:-}:" != *":${install_dir}:"* ]]; then
        echo "Note: add ${install_dir} to PATH to run ${command_name} from any directory."
    fi
}

mkdir -p "$(dirname "${PLIST_PATH}")" "${LOG_DIR}"

cat > "${PLIST_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${WRAPPER_SCRIPT}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>${PROJECT_ROOT}</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/sbin:/usr/sbin:/sbin</string>
        <key>PYTHONUNBUFFERED</key>
        <string>1</string>
    </dict>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/wechatapp.launchd.out.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/wechatapp.launchd.err.log</string>
</dict>
</plist>
EOF

plutil -lint "${PLIST_PATH}" >/dev/null

launchctl bootout "gui/${UID_VALUE}" "${PLIST_PATH}" >/dev/null 2>&1 || true
launchctl enable "gui/${UID_VALUE}/${LABEL}" >/dev/null 2>&1 || true
launchctl bootstrap "gui/${UID_VALUE}" "${PLIST_PATH}"
launchctl kickstart -k "gui/${UID_VALUE}/${LABEL}" >/dev/null 2>&1 || true

install_command "${GA_COMMAND}" "${GA_SCRIPT}"

echo "Installed and started: ${LABEL}"
echo "Plist: ${PLIST_PATH}"
echo "Logs: ${LOG_DIR}"
