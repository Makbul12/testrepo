#!/usr/bin/env bash
# Replace the ad-heavy Google TV home screen with a clean launcher.
# Usage: scripts/launcher.sh install   -> switch to the clean launcher
#        scripts/launcher.sh revert    -> bring back the stock Google TV home screen
source "$(dirname "$0")/common.sh"
require_device
STOCK=(com.google.android.apps.tv.launcherx com.google.android.tungsten.setupwraith)
CANDIDATES=(com.spocky.projengmenu me.efesser.flauncher)   # Projectivy, FLauncher

case "${1:-}" in
  install)
    new=""
    for c in "${CANDIDATES[@]}"; do is_installed "$c" && { new="$c"; break; }; done
    if [[ -z "$new" ]]; then
      echo "No replacement launcher is installed yet. Do this first, or the TV will have no home screen:"
      echo "  Play Store on the TV -> search 'Projectivy Launcher' -> Install"
      echo "  (or sideload FLauncher: adb install flauncher.apk)"
      exit 1
    fi
    echo "Replacement launcher found: $new"
    for p in "${STOCK[@]}"; do adb_sh pm disable-user --user 0 "$p"; done
    adb_sh input keyevent KEYCODE_HOME
    echo "Stock launcher disabled. Press HOME. If the TV asks, choose $new and pick 'Always'."
    ;;
  revert)
    for p in "${STOCK[@]}"; do adb_sh pm enable --user 0 "$p"; done
    adb_sh input keyevent KEYCODE_HOME
    echo "Stock Google TV home restored."
    ;;
  *) echo "Usage: $0 install|revert"; exit 1 ;;
esac
