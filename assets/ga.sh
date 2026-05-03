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
  ga start    Start the WeChat LaunchAgent
  ga stop     Stop and disable the WeChat LaunchAgent
  ga status   Show WeChat LaunchAgent status
EOF
}

cmd="${1:-status}"
shift || true

case "${cmd}" in
    start)
        exec /bin/bash "${SCRIPT_DIR}/start-wechat-launchagent.sh" "$@"
        ;;
    stop)
        exec /bin/bash "${SCRIPT_DIR}/stop-wechat-launchagent.sh" "$@"
        ;;
    status)
        exec /bin/bash "${SCRIPT_DIR}/status-wechat-launchagent.sh" "$@"
        ;;
    help|-h|--help)
        usage
        ;;
    *)
        echo "Unknown command: ${cmd}" >&2
        usage >&2
        exit 2
        ;;
esac
