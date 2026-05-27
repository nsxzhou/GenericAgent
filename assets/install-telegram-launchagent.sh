#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
    echo "This installer only supports macOS."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LABEL="com.genericagent.telegramapp"
GA_COMMAND="ga"
START_COMMAND="telegram-launchagent-start"
STOP_COMMAND="telegram-launchagent-stop"
STATUS_COMMAND="telegram-launchagent-status"
UPDATE_COMMAND="telegram-launchagent-update"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
LOG_DIR="${HOME}/Library/Logs/GenericAgent"
WRAPPER_SCRIPT="${PROJECT_ROOT}/assets/telegram_launchd.sh"
GA_SCRIPT="${PROJECT_ROOT}/assets/ga.sh"
START_SCRIPT="${PROJECT_ROOT}/assets/start-telegram-launchagent.sh"
STOP_SCRIPT="${PROJECT_ROOT}/assets/stop-telegram-launchagent.sh"
STATUS_SCRIPT="${PROJECT_ROOT}/assets/status-telegram-launchagent.sh"
UPDATE_SCRIPT="${PROJECT_ROOT}/assets/update-telegram-launchagent.sh"
UID_VALUE="$(id -u)"

if [[ ! -f "${PROJECT_ROOT}/frontends/tgapp.py" ]]; then
    echo "frontends/tgapp.py not found at ${PROJECT_ROOT}"
    exit 1
fi

for script in "${WRAPPER_SCRIPT}" "${GA_SCRIPT}" "${START_SCRIPT}" "${STOP_SCRIPT}" "${STATUS_SCRIPT}" "${UPDATE_SCRIPT}"; do
    if [[ ! -f "${script}" ]]; then
        echo "required script not found: ${script}"
        exit 1
    fi
done

validate_telegram_config() {
    local py_bin=""
    if [[ -x "${PROJECT_ROOT}/.venv/bin/python" ]]; then
        py_bin="${PROJECT_ROOT}/.venv/bin/python"
    elif [[ -x "${PROJECT_ROOT}/venv/bin/python" ]]; then
        py_bin="${PROJECT_ROOT}/venv/bin/python"
    elif command -v python3 >/dev/null 2>&1; then
        py_bin="$(command -v python3)"
    else
        echo "python3 not found"
        return 1
    fi

    "${py_bin}" - "${PROJECT_ROOT}" <<'PY'
import importlib.util
import pathlib
import sys

project_root = pathlib.Path(sys.argv[1])
mykey_path = project_root / "mykey.py"
if not mykey_path.exists():
    print("mykey.py not found. Configure Telegram first: tg_bot_token and tg_allowed_users.")
    raise SystemExit(1)

spec = importlib.util.spec_from_file_location("ga_launchagent_mykey", mykey_path)
module = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(module)
except Exception as exc:
    print(f"failed to load mykey.py: {exc}")
    raise SystemExit(1)

token = str(getattr(module, "tg_bot_token", "") or "").strip()
allowed = getattr(module, "tg_allowed_users", None)
if not token:
    print("tg_bot_token is missing or empty in mykey.py.")
    raise SystemExit(1)
if not isinstance(allowed, (list, tuple, set)) or not allowed:
    print("tg_allowed_users must be a non-empty list of Telegram numeric user IDs in mykey.py.")
    raise SystemExit(1)
normalized = [str(item).strip() for item in allowed]
if any(not item for item in normalized) or "*" in normalized:
    print("tg_allowed_users must contain explicit Telegram numeric user IDs; '*' is not supported by tgapp.py.")
    raise SystemExit(1)
if any(isinstance(item, bool) or not str(item).strip().isdigit() for item in allowed):
    print("tg_allowed_users entries must be numeric Telegram user IDs, for example: tg_allowed_users = [123456789].")
    raise SystemExit(1)
print("Telegram config ok.")
PY
}

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

validate_telegram_config
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
    <string>${LOG_DIR}/telegramapp.launchd.out.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/telegramapp.launchd.err.log</string>
</dict>
</plist>
EOF

plutil -lint "${PLIST_PATH}" >/dev/null

launchctl bootout "gui/${UID_VALUE}" "${PLIST_PATH}" >/dev/null 2>&1 || true
launchctl enable "gui/${UID_VALUE}/${LABEL}" >/dev/null 2>&1 || true
launchctl bootstrap "gui/${UID_VALUE}" "${PLIST_PATH}"
launchctl kickstart -k "gui/${UID_VALUE}/${LABEL}" >/dev/null 2>&1 || true

install_command "${GA_COMMAND}" "${GA_SCRIPT}"
install_command "${START_COMMAND}" "${START_SCRIPT}"
install_command "${STOP_COMMAND}" "${STOP_SCRIPT}"
install_command "${STATUS_COMMAND}" "${STATUS_SCRIPT}"
install_command "${UPDATE_COMMAND}" "${UPDATE_SCRIPT}"

echo "Installed and started: ${LABEL}"
echo "Plist: ${PLIST_PATH}"
echo "Logs: ${LOG_DIR}"
