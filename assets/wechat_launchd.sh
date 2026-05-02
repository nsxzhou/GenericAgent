#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${HOME}/Library/Logs/GenericAgent"
LOG_FILE="${LOG_DIR}/wechatapp.launchd.log"
VENV_DIR="${PROJECT_ROOT}/.venv"

mkdir -p "${LOG_DIR}" "${PROJECT_ROOT}/temp"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/sbin:/usr/sbin:/sbin:${PATH:-}"
export PYTHONUNBUFFERED=1
export PYTHONIOENCODING=utf-8

PYTHON_BIN=""
if [[ -n "${VIRTUAL_ENV:-}" && -x "${VIRTUAL_ENV}/bin/python" ]]; then
    PYTHON_BIN="${VIRTUAL_ENV}/bin/python"
elif [[ -x "${PROJECT_ROOT}/.venv/bin/python" ]]; then
    PYTHON_BIN="${PROJECT_ROOT}/.venv/bin/python"
elif [[ -x "${PROJECT_ROOT}/venv/bin/python" ]]; then
    PYTHON_BIN="${PROJECT_ROOT}/venv/bin/python"
elif command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3)"
else
    echo "[wechat-launchd] python3 not found" >> "${LOG_FILE}"
    exit 1
fi

ensure_wechat_deps() {
    local py_bin="$1"
    "${py_bin}" - <<'PY' >/dev/null 2>&1
import importlib.util
missing = [
    name for name in ("requests", "qrcode", "Crypto")
    if importlib.util.find_spec(name) is None
]
raise SystemExit(0 if not missing else 1)
PY
}

if ! ensure_wechat_deps "${PYTHON_BIN}"; then
    echo "[wechat-launchd] preparing isolated virtualenv" >> "${LOG_FILE}"
    if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
        "${PYTHON_BIN}" -m venv "${VENV_DIR}" >> "${LOG_FILE}" 2>&1
    fi
    PYTHON_BIN="${VENV_DIR}/bin/python"
    "${PYTHON_BIN}" -m pip install --upgrade pip setuptools wheel >> "${LOG_FILE}" 2>&1
    "${PYTHON_BIN}" -m pip install -e "${PROJECT_ROOT}[wechat]" >> "${LOG_FILE}" 2>&1
fi

cd "${PROJECT_ROOT}"
exec "${PYTHON_BIN}" frontends/wechatapp.py >> "${LOG_FILE}" 2>&1
