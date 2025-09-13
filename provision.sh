#!/usr/bin/env bash
set -euo pipefail

# provision.sh - one-click wrapper
# Env vars:
#   USERS_FILE (default: users.txt)
#   HOME_MODE  (default: 750)
#   UMASK      (default: 027)
#   DRY_RUN    (set to non-empty to simulate)

USERS_FILE=${USERS_FILE:-users.txt}
HOME_MODE=${HOME_MODE:-750}
UMASK=${UMASK:-027}

if [[ ${1:-} == "--dry-run" ]]; then
  DRY_RUN=1
fi

cmd=( sudo bash ./create_devs_ubuntu.sh -f "$USERS_FILE" --home-mode "$HOME_MODE" --umask "$UMASK" )
if [[ -n "${DRY_RUN:-}" ]]; then
  cmd+=( --dry-run )
fi

echo "[INFO] Executing: ${cmd[*]}"
"${cmd[@]}"

