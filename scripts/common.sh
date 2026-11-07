#!/usr/bin/env bash
# Shared helpers. Set ADB_SERIAL=192.168.1.50:5555 (for example) if more than one device is connected.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$ROOT/backups"
mkdir -p "$BACKUP_DIR"

command -v adb >/dev/null || { echo "adb not found. Install Android platform-tools first." >&2; exit 1; }

ADB=(adb)
[[ -n "${ADB_SERIAL:-}" ]] && ADB=(adb -s "$ADB_SERIAL")

adb_sh() { "${ADB[@]}" shell "$@" | tr -d '\r'; }

require_device() {
  local state
  state="$("${ADB[@]}" get-state 2>/dev/null || true)"
  if [[ "$state" != "device" ]]; then
    echo "No authorised device. Run: adb connect <TV-IP>:5555, then accept the prompt on the TV." >&2
    exit 1
  fi
  SERIAL="$("${ADB[@]}" get-serialno | tr -d '\r' | tr ':/' '__')"
  echo "Connected: $(adb_sh getprop ro.product.model) (Android $(adb_sh getprop ro.build.version.release))"
}

# Print the package names from a list file, without comments or blank lines.
read_list() { sed -e 's/#.*//' -e 's/[[:space:]]//g' "$1" | grep -v '^$' || true; }

is_installed() { adb_sh pm list packages --user 0 | grep -qx "package:$1"; }
