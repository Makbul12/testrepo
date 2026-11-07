#!/usr/bin/env bash
# Remove bloat for the current user. Each removal can be undone with restore.sh, and a factory reset also brings everything back.
# Usage: scripts/debloat.sh [safe|optional|path/to/list.txt] [--dry-run] [--yes]
source "$(dirname "$0")/common.sh"
target="${1:-safe}"; shift || true
DRY=0; YES=0
for a in "$@"; do case "$a" in --dry-run) DRY=1;; --yes) YES=1;; esac; done
case "$target" in
  safe|optional) list="$ROOT/lists/$target.txt" ;;
  *) list="$target" ;;
esac
[[ -f "$list" ]] || { echo "List not found: $list" >&2; exit 1; }

require_device
mapfile -t keep < <(read_list "$ROOT/lists/keep.txt")
log="$BACKUP_DIR/$SERIAL-removed.txt"

removed=0
while read -r pkg; do
  [[ -z "$pkg" ]] && continue
  if printf '%s\n' "${keep[@]}" | grep -qx "$pkg"; then
    echo "SKIP (protected) $pkg"; continue
  fi
  if ! is_installed "$pkg"; then
    echo "  -  not present   $pkg"; continue
  fi
  if (( DRY )); then echo "WOULD REMOVE     $pkg"; continue; fi
  if (( ! YES )); then
    read -r -p "Remove $pkg ? [y/N] " ans </dev/tty
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "  kept $pkg"; continue; }
  fi
  out="$(adb_sh pm uninstall -k --user 0 "$pkg" || true)"
  if [[ "$out" == *Success* ]]; then
    echo "REMOVED          $pkg"; echo "$pkg" >> "$log"; removed=$((removed+1))
  else
    # Some system apps refuse uninstall. Fall back to disabling them.
    out2="$(adb_sh pm disable-user --user 0 "$pkg" || true)"
    echo "DISABLED         $pkg  ($out2)"; echo "$pkg" >> "$log"; removed=$((removed+1))
  fi
done < <(read_list "$list")

echo; echo "Done. $removed package(s) changed. Log: $log"
(( DRY )) && echo "(dry run, nothing was changed)"
