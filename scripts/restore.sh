#!/usr/bin/env bash
# Bring back packages that debloat.sh removed or disabled.
# Usage: scripts/restore.sh            (restore everything in the log)
#        scripts/restore.sh <package>  (restore one package)
source "$(dirname "$0")/common.sh"
require_device
if [[ $# -gt 0 ]]; then pkgs=("$@"); else
  log="$BACKUP_DIR/$SERIAL-removed.txt"
  [[ -f "$log" ]] || { echo "No removal log at $log"; exit 1; }
  mapfile -t pkgs < <(sort -u "$log")
fi
for p in "${pkgs[@]}"; do
  adb_sh cmd package install-existing --user 0 "$p" >/dev/null 2>&1 || true
  adb_sh pm enable --user 0 "$p" >/dev/null 2>&1 || true
  echo "restored $p"
done
