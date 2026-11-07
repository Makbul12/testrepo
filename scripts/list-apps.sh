#!/usr/bin/env bash
# Show what is on the TV so you can decide what else to remove.
source "$(dirname "$0")/common.sh"
require_device
echo "== Apps you or the manufacturer installed (-3) =="; adb_sh pm list packages -3 | sed 's/package://' | sort
echo; echo "== Currently disabled =="; adb_sh pm list packages -d | sed 's/package://' | sort
