# Prayer-time speaker

Plays the azan (or a spoken announcement) on a Google Nest / Home speaker at each prayer time, with an
optional reminder a few minutes before. Runs on a Windows laptop on the same Wi-Fi as the speaker.

## Install (PowerShell on the laptop)

```powershell
irm https://raw.githubusercontent.com/makbul12/testrepo/claude/google-tv-bloatware-removal-yx9yti/prayer-speaker/install.ps1 | iex
```

It asks for your city, Asr timing, reminder minutes and speaker name, then starts itself at every log-on.

- Real azan: put `azan.mp3` (and optionally `fajr_azan.mp3`) in `%USERPROFILE%\PrayerSpeaker\audio`.
- Settings: `%USERPROFILE%\PrayerSpeaker\config.json` (`volume` 0.0 to 1.0, `prayers`, `reminder_minutes`).
- Log: `%USERPROFILE%\PrayerSpeaker\prayer.log`.
- Check: `py -3 %USERPROFILE%\PrayerSpeaker\prayer_cast.py --today` (times) or `--test` (play now).

The speaker is found by name, so a new IP address from the router does not break it. The laptop must be
awake and on the same Wi-Fi at prayer time. Night mode or Downtime in the Google Home app can silence it.

Prayer times: Aladhan API, method 1 (Karachi) and Hanafi Asr by default. Uninstall: delete
`PrayerSpeaker.lnk` from the Startup folder (`shell:startup`) and the `PrayerSpeaker` folder.
