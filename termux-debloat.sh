#!/data/data/com.termux/files/usr/bin/bash
# One-shot Google TV debloat from Termux on an Android phone.
# Usage:  bash termux-debloat.sh [TV_IP]      (default IP below)
TV_IP="${1:-192.168.0.103}"
TV="$TV_IP:5555"
LAUNCHER=com.spocky.projengmenu   # Projectivy Launcher

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

say "1/6 Installing adb in Termux (first run only)"
command -v adb >/dev/null || { pkg update -y && pkg install -y android-tools; }

say "2/6 Connecting to TV at $TV"
adb disconnect "$TV" >/dev/null 2>&1
adb connect "$TV"
echo "If the TV shows 'Allow USB debugging?', tick 'Always allow' and press OK."
for i in $(seq 1 30); do
  [ "$(adb -s "$TV" get-state 2>/dev/null)" = device ] && break
  sleep 2
done
[ "$(adb -s "$TV" get-state 2>/dev/null)" = device ] || { echo "Could not connect. Check USB debugging is ON and run again."; exit 1; }
A() { adb -s "$TV" shell "$@" | tr -d '\r'; }
echo "Connected to: $(A getprop ro.product.model)"
echo "Storage before: $(A df -h /data | tail -1)"

say "3/6 Removing bloatware (reversible)"
for p in \
  com.google.android.youtube.tvmusic com.google.android.youtube.tvkids \
  com.google.android.play.games com.google.android.apps.tv.dreamx \
  com.android.dreams.basic com.android.dreams.phototable \
  com.google.android.feedback com.android.printspooler \
  com.google.android.partnersetup com.google.android.tvtutorials \
  com.google.android.tvrecommendations com.google.android.leanbacklauncher.recommendations \
  com.google.android.apps.turbo com.google.android.marvin.talkback
do
  if A pm list packages | grep -qx "package:$p"; then
    r="$(A pm uninstall -k --user 0 "$p")"
    case "$r" in *Success*) echo "  removed  $p";; *) A pm disable-user --user 0 "$p" >/dev/null && echo "  disabled $p";; esac
  fi
done

say "4/6 Clean launcher (Projectivy)"
if ! A pm list packages | grep -qx "package:$LAUNCHER"; then
  echo "Opening Projectivy Launcher in the TV's Play Store. Press INSTALL on the TV."
  A am start -a android.intent.action.VIEW -d "market://details?id=$LAUNCHER" >/dev/null
  echo "Waiting up to 5 minutes for it to install..."
  for i in $(seq 1 60); do
    A pm list packages | grep -qx "package:$LAUNCHER" && break
    sleep 5
  done
fi
if A pm list packages | grep -qx "package:$LAUNCHER"; then
  A pm disable-user --user 0 com.google.android.apps.tv.launcherx >/dev/null
  A pm disable-user --user 0 com.google.android.tungsten.setupwraith >/dev/null
  A input keyevent KEYCODE_HOME
  echo "  Google TV home disabled. Projectivy is now the home screen."
  echo "  (If the TV asks which home app to use, pick Projectivy -> Always.)"
else
  echo "  Projectivy not installed - skipped launcher swap (stock home kept, TV is safe)."
fi

say "5/6 Clearing all app caches (storage trick)"
A pm trim-caches 999G
echo "Storage after: $(A df -h /data | tail -1)"

say "6/6 Speeding up animations"
A settings put global window_animation_scale 0.5
A settings put global transition_animation_scale 0.5
A settings put global animator_duration_scale 0.5

say "ALL DONE"
cat <<'MSG'
To UNDO the launcher swap, run in Termux:
  adb shell pm enable com.google.android.apps.tv.launcherx
  adb shell pm enable com.google.android.tungsten.setupwraith
A factory reset on the TV restores everything else.
MSG
