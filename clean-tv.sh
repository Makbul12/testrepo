#!/data/data/com.termux/files/usr/bin/bash
# Clean Your TV (github.com/Gathin23/cleanyourtv) from Termux on an Android phone.
# Uses the project's own tools: its debloat list for your TV model, its Wi-Fi and Home safety checks,
# its restore record, and its launcher (built by this repo's GitHub Action).
# Usage:  bash clean-tv.sh [TV_IP]
set -u
AUTO=0
if [ "${1:-}" = --auto ]; then AUTO=1; shift; fi
if [ "${1:-}" = --restore ]; then
  RESTORE=1; shift
else RESTORE=0; fi
TV_IP="${1:-192.168.0.103}"
CYT_COMMIT=3f175120f9802ab4364f61d040db9aa78ec71493
APK_URL=https://github.com/makbul12/testrepo/releases/download/cleanyourtv-launcher/cleanyourtv-launcher.apk
DIR="$HOME/cleanyourtv"
say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31mSTOPPED: %s\033[0m\n' "$*"; exit 1; }

say "1/6 Installing tools in Termux (first run takes a few minutes)"
pkg upgrade -y -o Dpkg::Options::=--force-confnew </dev/null
pkg install -y git python python-cryptography android-tools curl </dev/null || die "package install failed"
adb version >/dev/null 2>&1 || die "adb does not run. Run 'pkg upgrade' and try again."

say "2/6 Getting Clean Your TV"
if [ ! -d "$DIR/.git" ]; then git clone -q https://github.com/Gathin23/cleanyourtv "$DIR" || die "clone failed"; fi
cd "$DIR" && git fetch -q origin && git checkout -q "$CYT_COMMIT" || die "could not check out Clean Your TV"
if [ ! -x tools/venv/bin/python ]; then
  python -m venv --system-site-packages tools/venv && tools/venv/bin/pip install -q adb-shell==0.4.4 rsa==4.9.1 </dev/null \
    || die "python setup failed"
fi
mkdir -p launcher/app/build/outputs/apk/release
curl -fsSL -o launcher/app/build/outputs/apk/release/app-release.apk "$APK_URL" || die "launcher download failed"

say "3/6 Connecting to the TV at $TV_IP"
adb connect "$TV_IP:5555" </dev/null
echo "If the TV asks 'Allow USB debugging?', tick 'Always allow' and press OK."
for i in $(seq 1 30); do [ "$(adb -s "$TV_IP:5555" get-state 2>/dev/null)" = device ] && break; sleep 2; done
[ "$(adb -s "$TV_IP:5555" get-state 2>/dev/null)" = device ] || die "TV not connected. Check USB debugging is on, then run again."
export TV_HOST="$TV_IP" TV_ADB_BINARY="$(command -v adb)"
tv() { tools/venv/bin/python -I tools/tv.py "$@" </dev/null | tr -d '\r'; }
MODEL=$(tv 'getprop ro.product.model'); DEVICE=$(tv 'getprop ro.product.device'); BRAND=$(tv 'getprop ro.product.brand')
echo "TV: $BRAND $MODEL (device: $DEVICE)"

if [ "$RESTORE" = 1 ]; then
  say "Restoring the stock TV"
  L=$(cat "$HOME/.cleanyourtv-list" 2>/dev/null || true)
  if [ -n "$L" ]; then bash tools/restore.sh "$L" com.google.android.apps.tv.launcherx; else
    tv 'pm enable --user 0 com.google.android.apps.tv.launcherx; pm enable --user 0 com.google.android.tungsten.setupwraith; input keyevent KEYCODE_HOME'; fi
  say "Restored"; exit 0
fi

say "4/6 Finding the debloat list for this TV"
LIST=""
for key in "$DEVICE" "$MODEL"; do
  [ -n "$key" ] || continue
  LIST=$(grep -liwF -- "$key" examples/*/debloat.txt examples/*/tv.json 2>/dev/null | head -n1 | sed 's#/tv.json$#/debloat.txt#')
  [ -n "$LIST" ] && [ -f "$LIST" ] && break; LIST=""
done
if [ -n "$LIST" ]; then
  echo "Matched list: $LIST"
  sed -n '1,4p' "$LIST"
  if [ "$AUTO" = 1 ]; then echo "(auto mode: using it)"; else
    read -r -p "Use this list? [Y/n] " a; case "$a" in [Nn]*) LIST="";; esac; fi
fi
if [ -z "$LIST" ]; then
  echo "No exact list for this model. Lists for similar Google TVs:"
  ls -d examples/*google-tv* examples/*chromecast* examples/sony-* 2>/dev/null | sed 's#examples/##' | column -c 70 2>/dev/null || true
  read -r -p "Type a folder name from above, or press Enter to only install the launcher: " f
  [ -n "$f" ] && [ -f "examples/$f/debloat.txt" ] && LIST="examples/$f/debloat.txt"
fi

# Let the user choose, app by app, from what is actually installed on this TV.
if [ -n "$LIST" ]; then
  say "Review: choose what to remove (Enter = yes, n = keep, a = yes to all the rest)"
  INSTALLED=$(tv 'pm list packages' | sed 's/^package://')
  MY="my-debloat.txt"; : > "$MY"; ALL=$AUTO
  # Everyday apps and features that are never removed in auto mode: streaming apps, the Play Store,
  # the remote's voice button, casting from phones, the on-screen keyboard and speech.
  KEEP_DAILY=" com.google.android.youtube.tv com.google.android.youtube.tvunplugged com.netflix.ninja
    com.amazon.amazonvideo.livingroom com.disney.disneyplus in.startv.hotstar in.startv.hotstar.dplus.tv
    com.jio.media.stb.ondemand com.jio.jioplay.tv com.sonyliv com.graymatrix.did com.spotify.tv.android
    com.apple.atve.androidtv.appletv com.hbo.hbonow com.plexapp.android com.android.vending
    com.google.android.katniss com.google.android.apps.mediashell com.google.android.tts
    com.google.android.leanback.ime com.google.android.inputmethod.latin com.google.android.tvkeyboard
    com.google.android.tv.remote.service com.google.android.apps.tv.remote.service "
  while IFS= read -r line; do
    pkg=$(printf '%s' "$line" | sed 's/#.*//; s/[[:space:]]//g')
    if [ -z "$pkg" ] || ! printf '%s\n' "$INSTALLED" | grep -qxF "$pkg"; then printf '%s\n' "$line" >> "$MY"; continue; fi
    case "$pkg" in com.google.android.apps.tv.launcherx|com.google.android.tungsten.setupwraith)
      printf '%s\n' "$line" >> "$MY"; continue ;; esac   # needed for the new launcher to take over Home
    note=$(printf '%s' "$line" | sed -n 's/^[^#]*#[[:space:]]*//p')
    if [ "$AUTO" = 1 ] && printf '%s' "$KEEP_DAILY" | tr -s ' \n' '\n\n' | grep -qxF "$pkg"; then
      printf '# kept (daily use): %s\n' "$line" >> "$MY"; echo "  keeping  $pkg (daily use)"; continue
    fi
    [ "$AUTO" = 1 ] && echo "  removing $pkg${note:+  ($note)}"
    if [ "$ALL" = 1 ]; then ans=y; else
      read -r -p "  Remove $pkg${note:+  ($note)}? [Y/n/a] " ans </dev/tty; fi
    case "$ans" in [Nn]*) printf '# kept: %s\n' "$line" >> "$MY"; echo "    keeping";;
      [Aa]*) ALL=1; printf '%s\n' "$line" >> "$MY";; *) printf '%s\n' "$line" >> "$MY";; esac
  done < "$LIST"
  LIST="$MY"
fi

if [ -n "$LIST" ]; then
  say "5/6 Debloating with $LIST (Clean Your TV checks Wi-Fi and Home before each step)"
  echo "$LIST" > "$HOME/.cleanyourtv-list"
  bash tools/disable.sh "$LIST" || die "debloat stopped. Send a screenshot."
else
  say "5/6 Debloat skipped (no list chosen)"
fi

say "6/6 Installing the Clean Your TV launcher"
( cd launcher && SKIP_BUILD=1 INPUT_KEY_SERVICE=1 bash ./build-and-install.sh ) \
  || die "launcher install did not finish. The stock home was kept or put back. Send a screenshot."
# Second pass: anything the list skipped while the stock launcher still owned Home.
[ -n "$LIST" ] && { bash tools/disable.sh "$LIST" || true; }
tv 'pm trim-caches 999G' >/dev/null && echo "App caches cleared."
# Snappier menus: halve the animation time (set back to 1 to undo).
tv 'settings put global window_animation_scale 0.5; settings put global transition_animation_scale 0.5; settings put global animator_duration_scale 0.5' >/dev/null && echo "Animations sped up."

say "ALL DONE"
echo "Undo everything later with:  bash clean.sh --restore   (or see README in $DIR)"
