#!/bin/bash
# Prayer-time announcements on a Google Nest speaker using Google Home's own automations.
# Nothing needs to stay on: the Mac only makes the automation text. Run it again every 2 weeks.
#   curl -fsSL <raw URL of this file> | bash
set -euo pipefail
REF="claude/google-tv-bloatware-removal-yx9yti"
BASE="https://raw.githubusercontent.com/makbul12/testrepo/$REF/prayer-speaker/google-home"
CONF="$HOME/.prayer-google-home.json"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
ask() { local v; read -r -p "$1" v </dev/tty; printf '%s' "$v"; }
jget() { /usr/bin/plutil -extract "$1" raw -o - "$CONF" 2>/dev/null || true; }
jesc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

if [ -f "$CONF" ] && [ "${1:-}" != "--setup" ]; then
  CITY=$(jget city); COUNTRY=$(jget country); SCHOOL=$(jget school); SPEAKER=$(jget speaker); REM=$(jget reminder_minutes)
  echo "Using saved settings: $CITY, $COUNTRY; speaker '${SPEAKER:-all speakers}'. (Run with --setup to change.)"
else
  CITY=$(ask "City (for example Bengaluru): ")
  COUNTRY=$(ask "Country [India]: "); COUNTRY=${COUNTRY:-India}
  A=$(ask "Asr timing: 1 = Hanafi (common in India), 0 = Shafi'i [1]: "); SCHOOL=$([ "$A" = 0 ] && echo 0 || echo 1)
  echo "Speaker name exactly as in the Google Home app, then ' - ' and its room, for example: Nest Mini - Bedroom"
  SPEAKER=$(ask "Speaker (Enter = announce on all speakers): ")
  REM=$(ask "Reminder how many minutes before each prayer? (0 = none) [10]: "); REM=${REM:-10}
  printf '{"city":"%s","country":"%s","school":%s,"speaker":"%s","reminder_minutes":%s,"days":15}\n' \
    "$(jesc "$CITY")" "$(jesc "$COUNTRY")" "$SCHOOL" "$(jesc "$SPEAKER")" "$REM" > "$CONF"
fi

echo "Getting prayer times for $CITY..."
curl -fsSL -o "$TMP/build.js" "$BASE/build.js"
Y=$(date +%Y); M=$(date +%-m)
NY=$(date -v1d -v+1m +%Y); NM=$(date -v1d -v+1m +%-m)
for ym in "$Y $M 1" "$NY $NM 2"; do
  set -- $ym
  curl -fsSL --get "https://api.aladhan.com/v1/calendarByCity/$1/$2" \
    --data-urlencode "city=$CITY" --data-urlencode "country=$COUNTRY" \
    --data-urlencode "method=1" --data-urlencode "school=$SCHOOL" -o "$TMP/m$3.json"
done

OUT=$(osascript -l JavaScript "$TMP/build.js" "$CONF" "$TMP/m1.json" "$TMP/m2.json")
printf '%s\n' "$OUT" | sed '/^#SUMMARY#$/,$d' | pbcopy
UNTIL=$(printf '%s\n' "$OUT" | sed -n 's/^#UNTIL#//p')

echo
echo "Times used (the latest of the next 15 days, so the call is never early):"
printf '%s\n' "$OUT" | sed -n '/^#SUMMARY#$/,/^#UNTIL#/p' | sed '1d;$d' | sed 's/^/  /'
echo
echo "DONE. The automation is copied. Now, in the browser that just opened:"
echo "  1. Sign in, open Automations, and delete last time's 'Prayer times' automation if there is one."
echo "  2. Click 'Add new' (script editor), select everything in the box and paste (Cmd+V)."
echo "  3. Click Validate, then Save. Make sure it is switched on."
echo "Run this command again on or after $UNTIL to update the times."
open "https://home.google.com/"
