#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
    echo "This updater only supports macOS."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LABEL="com.genericagent.telegramapp"
LOG_DIR="${HOME}/Library/Logs/GenericAgent"
LOG_FILE="${LOG_DIR}/telegramapp.update.log"
UID_VALUE="$(id -u)"
REMOTE="${TELEGRAM_UPDATE_REMOTE:-origin}"
BRANCH="${TELEGRAM_UPDATE_BRANCH:-my-feature}"
RESTART_DELAY="${TELEGRAM_UPDATE_RESTART_DELAY:-2}"

mkdir -p "${LOG_DIR}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${LOG_FILE}"
}

restart_telegram_later() {
    (
        sleep "${RESTART_DELAY}"
        launchctl kickstart -k "gui/${UID_VALUE}/${LABEL}" >> "${LOG_FILE}" 2>&1 || true
    ) >/dev/null 2>&1 &
}

cd "${PROJECT_ROOT}"
log "update requested: remote=${REMOTE} branch=${BRANCH}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log "not a git worktree: ${PROJECT_ROOT}"
    exit 1
fi

CURRENT_BRANCH="$(git branch --show-current)"
if [[ "${CURRENT_BRANCH}" != "${BRANCH}" ]]; then
    log "skip: current branch is ${CURRENT_BRANCH:-detached}, expected ${BRANCH}"
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    log "skip: worktree has uncommitted changes"
    git status --short >> "${LOG_FILE}" 2>&1 || true
    exit 1
fi

git fetch "${REMOTE}" "+refs/heads/${BRANCH}:refs/remotes/${REMOTE}/${BRANCH}" >> "${LOG_FILE}" 2>&1

LOCAL_SHA="$(git rev-parse HEAD)"
REMOTE_SHA="$(git rev-parse "refs/remotes/${REMOTE}/${BRANCH}")"

if [[ "${LOCAL_SHA}" != "${REMOTE_SHA}" ]]; then
    log "fast-forward ${LOCAL_SHA} -> ${REMOTE_SHA}"
    git merge --ff-only "refs/remotes/${REMOTE}/${BRANCH}" >> "${LOG_FILE}" 2>&1
else
    log "already up to date at ${LOCAL_SHA}; restarting anyway"
fi

log "scheduling restart for ${LABEL}"
restart_telegram_later
log "update script finished"
