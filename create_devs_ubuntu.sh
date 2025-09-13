#!/usr/bin/env bash
set -euo pipefail

# create_devs_ubuntu.sh
# Create multiple developer users on Ubuntu with safe isolation.
# - Creates local users with user-private group, bash shell, and home dir
# - Disables passwords by default (SSH keys recommended)
# - Sets home permissions to 750 (others cannot read)
# - Optionally installs SSH authorized_keys per user
#
# Input format (default: users.txt):
#   username[:ssh_pubkey]
# - Lines starting with # or empty lines are ignored
# - You can leave ssh_pubkey empty to keep account password-disabled
#
# Usage:
#   sudo bash scripts/create_devs_ubuntu.sh [-f users.txt] [--umask 027] [--home-mode 750] [--dry-run]

usage() {
  cat <<EOF
Usage: sudo $0 [-f users.txt] [--umask 027] [--home-mode 750] [--dry-run]

Options:
  -f FILE        File with lines: username[:ssh_pubkey]
  --umask MODE   Default umask to suggest for users (no system change)
  --home-mode M  chmod mode to apply to each home (default: 750)
  --dry-run      Print actions without applying

Notes:
  - This script targets Ubuntu/Debian (uses adduser).
  - Accounts are created with disabled passwords; use SSH keys or set passwords later.
  - It does NOT grant sudo. Add explicitly if needed: usermod -aG sudo USER
EOF
}

require_root() {
  if [[ $(id -u) -ne 0 ]]; then
    echo "[ERROR] Run as root (use sudo)." >&2
    exit 1
  fi
}

valid_username() {
  local u="$1"
  # POSIX-ish username rule: start with a-z_, then a-z0-9_- up to 32 chars
  [[ "$u" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

file="users.txt"
UMASK_SUGGEST="027"
HOME_MODE="750"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0;;
    -f) file="$2"; shift 2;;
    --umask) UMASK_SUGGEST="$2"; shift 2;;
    --home-mode) HOME_MODE="$2"; shift 2;;
    --dry-run) DRY_RUN=true; shift;;
    *) echo "[ERROR] Unknown argument: $1" >&2; usage; exit 2;;
  esac
done

require_root

if [[ ! -f "$file" ]]; then
  echo "[ERROR] Input file not found: $file" >&2
  exit 1
fi

echo "[INFO] Reading users from $file"

create_user() {
  local user="$1"
  if id "$user" >/dev/null 2>&1; then
    echo "[OK] User exists: $user"
    return 0
  fi
  echo "[ADD] Creating user: $user"
  if $DRY_RUN; then
    return 0
  fi
  # Non-interactive adduser: disabled password, empty gecos
  DEBIAN_FRONTEND=noninteractive adduser --disabled-password --gecos "" --shell /bin/bash "$user"
}

set_home_mode() {
  local user="$1"; local mode="$2"
  local home
  home=$(getent passwd "$user" | cut -d: -f6 || true)
  if [[ -z "$home" || ! -d "$home" ]]; then
    echo "[WARN] Home not found for $user"
    return 0
  fi
  echo "[PERM] chmod $mode $home"
  $DRY_RUN || chmod "$mode" "$home"
}

ensure_ssh_key() {
  local user="$1"; local pubkey="$2"
  if [[ -z "$pubkey" ]]; then
    echo "[SSH] No key provided for $user (password login remains disabled)"
    return 0
  fi
  local home; home=$(getent passwd "$user" | cut -d: -f6 || true)
  local sshd="$home/.ssh"
  echo "[SSH] Installing authorized_keys for $user"
  if $DRY_RUN; then
    return 0
  fi
  install -d -m 700 -o "$user" -g "$user" "$sshd"
  touch "$sshd/authorized_keys"
  chown "$user:$user" "$sshd/authorized_keys"
  chmod 600 "$sshd/authorized_keys"
  # Append if not already present
  grep -qxF "$pubkey" "$sshd/authorized_keys" 2>/dev/null || echo "$pubkey" >> "$sshd/authorized_keys"
}

disable_password_login() {
  local user="$1"
  echo "[LOCK] Disabling password for $user"
  $DRY_RUN || passwd -l "$user" >/dev/null
}

suggest_umask_note() {
  local user="$1"; local um="$2"
  local home; home=$(getent passwd "$user" | cut -d: -f6 || true)
  local note="$home/.profile"
  echo "[NOTE] Suggesting umask $um in $note (commented)"
  if $DRY_RUN; then
    return 0
  fi
  if ! grep -q "create_devs_ubuntu" "$note" 2>/dev/null; then
    cat >> "$note" <<EOT

# Added by create_devs_ubuntu on $(date)
# For tighter defaults when creating files, consider:
# umask $um  # uncomment to apply per-user
EOT
    chown "$user:$user" "$note" || true
  fi
}

while IFS= read -r line || [[ -n "$line" ]]; do
  # Trim
  line="${line%%$'\r'}"  # strip CR if present
  [[ -z "$line" || "$line" =~ ^\s*# ]] && continue

  user="${line%%:*}"
  key=""
  if [[ "$line" == *:* ]]; then
    key="${line#*:}"
  fi

  user=$(echo -n "$user" | tr '[:upper:]' '[:lower:]')

  if ! valid_username "$user"; then
    echo "[ERROR] Invalid username: '$user'" >&2
    exit 1
  fi

  create_user "$user"
  set_home_mode "$user" "$HOME_MODE"
  ensure_ssh_key "$user" "$key"
  disable_password_login "$user"
  suggest_umask_note "$user" "$UMASK_SUGGEST"
done < "$file"

echo "[DONE] Processed users from $file"
echo "[INFO] Verify: id USER | getent passwd USER | ls -ld ~USER"
