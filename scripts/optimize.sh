#!/usr/bin/env bash
# Free storage and make the UI feel faster. Nothing here deletes your apps or logins.
source "$(dirname "$0")/common.sh"
require_device
echo "Storage before:"; adb_sh df -h /data | tail -1

# The well-known storage trick: ask Android to trim every app cache.
# Asking for an impossibly large amount makes it clear all caches.
adb_sh pm trim-caches 999G
echo "App caches cleared."

# Faster-feeling UI (set the scales back to 1 to undo).
adb_sh settings put global window_animation_scale 0.5
adb_sh settings put global transition_animation_scale 0.5
adb_sh settings put global animator_duration_scale 0.5
echo "Animation scales set to 0.5x."

# Background compile apps for smoother launches. This can take several minutes.
if [[ "${1:-}" == "--compile" ]]; then
  echo "Compiling apps (speed-profile)…"
  adb_sh cmd package compile -m speed-profile -a >/dev/null || true
fi

echo "Storage after:"; adb_sh df -h /data | tail -1
