#!/usr/bin/env bash
set -euo pipefail

resolve_script_dir() {
    local source="${BASH_SOURCE[0]}"
    local dir target

    while [[ -L "${source}" ]]; do
        dir="$(cd -P "$(dirname "${source}")" && pwd)"
        target="$(readlink "${source}")"
        if [[ "${target}" == /* ]]; then
            source="${target}"
        else
            source="${dir}/${target}"
        fi
    done

    cd -P "$(dirname "${source}")" && pwd
}

SCRIPT_DIR="$(resolve_script_dir)"

usage() {
    cat <<'EOF'
Usage:
  ga wechat start      Start the WeChat LaunchAgent
  ga wechat stop       Stop and disable the WeChat LaunchAgent
  ga wechat status     Show WeChat LaunchAgent status
  ga wechat update     Update the WeChat LaunchAgent service

  ga telegram start    Start the Telegram LaunchAgent
  ga telegram stop     Stop and disable the Telegram LaunchAgent
  ga telegram status   Show Telegram LaunchAgent status
  ga telegram update   Update the Telegram LaunchAgent service
EOF
}

platform="${1:-}"
cmd="${2:-}"
if [[ -n "${platform}" ]]; then
    shift || true
fi
if [[ -n "${cmd}" ]]; then
    shift || true
fi

case "${platform}:${cmd}" in
    wechat:start)
        exec /bin/bash "${SCRIPT_DIR}/start-wechat-launchagent.sh" "$@"
        ;;
    wechat:stop)
        exec /bin/bash "${SCRIPT_DIR}/stop-wechat-launchagent.sh" "$@"
        ;;
    wechat:status)
        exec /bin/bash "${SCRIPT_DIR}/status-wechat-launchagent.sh" "$@"
        ;;
    wechat:update)
        exec /bin/bash "${SCRIPT_DIR}/update-wechat-launchagent.sh" "$@"
        ;;
    telegram:start)
        exec /bin/bash "${SCRIPT_DIR}/start-telegram-launchagent.sh" "$@"
        ;;
    telegram:stop)
        exec /bin/bash "${SCRIPT_DIR}/stop-telegram-launchagent.sh" "$@"
        ;;
    telegram:status)
        exec /bin/bash "${SCRIPT_DIR}/status-telegram-launchagent.sh" "$@"
        ;;
    telegram:update)
        exec /bin/bash "${SCRIPT_DIR}/update-telegram-launchagent.sh" "$@"
        ;;
    :|help:|-h:|--help:|wechat:help|wechat:-h|wechat:--help|telegram:help|telegram:-h|telegram:--help)
        usage
        ;;
    help|-h|--help)
        usage
        ;;
    *)
        if [[ "${platform}" == "start" || "${platform}" == "stop" || "${platform}" == "status" || "${platform}" == "update" ]]; then
            echo "Missing platform. Use: ga wechat ${platform} or ga telegram ${platform}" >&2
        else
            echo "Unknown command: ${platform}${cmd:+ ${cmd}}" >&2
        fi
        usage >&2
        exit 2
        ;;
esac
