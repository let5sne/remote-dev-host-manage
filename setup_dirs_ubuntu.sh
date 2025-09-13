#!/usr/bin/env bash
set -euo pipefail

# setup_dirs_ubuntu.sh
# Create and manage shared project directories and groups on Ubuntu/Debian.
# - Creates a Unix group (if missing)
# - Adds users to the group (optional)
# - Creates a workspace directory with setgid bit and default ACLs
# - Modes default to 2770 (group-collab, no world access)
#
# Usage examples:
#   sudo bash setup_dirs_ubuntu.sh --group proj-alpha --path /srv/projects/alpha --users alice,bob
#   sudo bash setup_dirs_ubuntu.sh --group proj-alpha --path /srv/projects/alpha --mode 2775
#   sudo bash setup_dirs_ubuntu.sh --group proj-alpha --path /srv/projects/alpha --sticky
#
# Options:
#   --group NAME        Group to own the directory (required)
#   --path DIR          Directory to create/manage (required)
#   --users LIST        Comma-separated users to add to the group
#   --mode MODE         Directory mode (default 2770)
#   --sticky            Add sticky bit (+t) to prevent cross-deletion (mode 1xxx)
#   --dry-run           Print actions without applying

usage() {
  cat <<EOF
Usage: sudo $0 --group NAME --path DIR [--users alice,bob] [--mode 2770] [--sticky] [--dry-run]
EOF
}

require_root() { if [[ $(id -u) -ne 0 ]]; then echo "Run as root" >&2; exit 1; fi; }

GROUP=""
PATH_DIR=""
USERS=""
MODE="2770"
STICKY=false
DRY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --group) GROUP="$2"; shift 2;;
    --path) PATH_DIR="$2"; shift 2;;
    --users) USERS="$2"; shift 2;;
    --mode) MODE="$2"; shift 2;;
    --sticky) STICKY=true; shift;;
    --dry-run) DRY=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

[[ -z "$GROUP" || -z "$PATH_DIR" ]] && { usage; exit 2; }
require_root

run() { echo "+ $*"; $DRY || eval "$*"; }

if ! getent group "$GROUP" >/dev/null; then
  run groupadd "$GROUP"
else
  echo "[OK] Group exists: $GROUP"
fi

if [[ -n "$USERS" ]]; then
  IFS=',' read -r -a arr <<< "$USERS"
  for u in "${arr[@]}"; do
    u=$(echo "$u" | xargs)
    [[ -z "$u" ]] && continue
    if id "$u" >/dev/null 2>&1; then
      echo "[ADD] $u -> $GROUP"
      run usermod -aG "$GROUP" "$u"
    else
      echo "[WARN] user not found: $u"
    fi
  done
fi

# Create directory with setgid and group ownership
RUN_MODE="$MODE"
if $STICKY; then
  # Ensure sticky bit present
  case "$RUN_MODE" in
    1*) : ;; # already has sticky
    *) RUN_MODE="1$RUN_MODE";;
  esac
fi

run install -d -m "$RUN_MODE" -o root -g "$GROUP" "$PATH_DIR"

# Ensure group rwx via ACLs and defaults for new files/dirs (if setfacl available)
if command -v setfacl >/dev/null 2>&1; then
  run setfacl -R -m g:"$GROUP":rwx "$PATH_DIR"
  run setfacl -R -m d:g:"$GROUP":rwx "$PATH_DIR"
else
  echo "[WARN] 'setfacl' not found; install package 'acl' or run 'make deps'. Skipping ACL defaults."
fi

echo "[DONE] $PATH_DIR owned by :$GROUP with mode $RUN_MODE"
echo "[TIP] New files will inherit group via setgid; ACL default ensures group rwx."
