#!/usr/bin/env bash
# Save a snapshot of every package and its state before you change anything.
source "$(dirname "$0")/common.sh"
require_device
ts="$(date +%Y%m%d-%H%M%S)"
adb_sh pm list packages -u   > "$BACKUP_DIR/$SERIAL-all-$ts.txt"
adb_sh pm list packages -d   > "$BACKUP_DIR/$SERIAL-disabled-$ts.txt"
adb_sh pm list packages -3   > "$BACKUP_DIR/$SERIAL-thirdparty-$ts.txt"
adb_sh df -h /data           > "$BACKUP_DIR/$SERIAL-storage-$ts.txt"
echo "Snapshot saved to $BACKUP_DIR (*-$ts.txt)"
