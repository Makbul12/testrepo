# Google TV Debloat Kit

Remove bloatware from a Google TV (Chromecast with Google TV, Sony, TCL, Hisense and similar), replace the ad-filled home screen with a clean launcher, and free up storage. No root needed. Every step can be undone.

## 1. One-time setup

1. On the TV: **Settings → System → About**, then click **Android TV OS build** 7 times to turn on Developer options.
2. **Settings → System → Developer options**, then turn on **USB debugging** (and **Wireless debugging** if your TV shows it).
3. Find the TV's IP address: **Settings → Network & Internet → (your Wi-Fi)**.
4. On your computer, install [Android platform-tools](https://developer.android.com/tools/releases/platform-tools) (`brew install android-platform-tools` on a Mac), then run:
   ```bash
   adb connect 192.168.1.50:5555      # your TV's IP
   ```
   Accept the **Allow USB debugging?** prompt on the TV and tick **Always allow**.
   (On Google TV 12+, Wireless debugging may need `adb pair IP:PORT` with the code shown on screen.)

## 2. Run it, in this order

```bash
scripts/backup.sh                      # snapshot of all packages + storage
scripts/debloat.sh safe --dry-run      # preview
scripts/debloat.sh safe                # asks y/N for each app (add --yes to skip the prompts)
scripts/list-apps.sh                   # see what's left
scripts/debloat.sh optional            # streaming apps, Assistant, casting: pick what you don't use

# Clean launcher: FIRST install "Projectivy Launcher" from the Play Store on the TV
scripts/launcher.sh install            # disables the stock Google TV home

scripts/optimize.sh                    # clears all app caches + speeds up animations
scripts/optimize.sh --compile          # optional, also pre-compiles apps (takes a few minutes)
```

If you have more than one device connected, prefix the commands with `ADB_SERIAL=192.168.1.50:5555`.

## What each list covers

| File | Contents |
|---|---|
| `lists/safe.txt` | YouTube Music/Kids, Play Games, screensavers, feedback, print spooler, tutorials, recommendations, Device Health |
| `lists/optional.txt` | Netflix, Prime, Disney+, Spotify, Apple TV, Max, Plex, Google TV content app, **Assistant/voice**, **Chromecast built-in** |
| `lists/keep.txt` | Play Services, Play Store, remote pairing, settings and others. The script refuses to remove these |

Edit the lists freely, or pass your own file: `scripts/debloat.sh my-list.txt`.

## The "storage hack"

`optimize.sh` runs `pm trim-caches 999G`. That asks Android to free 999 GB of cache, which is impossible, so it clears every app's cache. This is often several GB on a TV. Logins and app data stay. Caches rebuild over time, so rerun it every month or two.

## Undo

```bash
scripts/launcher.sh revert                 # stock Google TV home back
scripts/restore.sh                         # restore everything debloat.sh removed
scripts/restore.sh com.netflix.ninja       # restore one app
adb shell settings put global window_animation_scale 1   # (also transition_/animator_duration_scale)
```

Removals use `pm uninstall --user 0`, so the APK stays in the system image. **Settings → Factory reset** always brings back the original state.

## Notes

- Install the replacement launcher **before** running `launcher.sh install`. The script checks for this.
- Removing `com.google.android.katniss` stops the remote's voice button. Removing `mediashell` stops casting.
- Some TV updates re-enable the stock launcher. If that happens, run `scripts/launcher.sh install` again.
