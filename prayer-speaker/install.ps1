# Prayer-time speaker: one-time setup on a Windows laptop.
# Run in PowerShell:  irm <raw URL of this file> | iex
$ErrorActionPreference = 'Stop'
$Ref  = 'claude/google-tv-bloatware-removal-yx9yti'
$Base = "https://raw.githubusercontent.com/makbul12/testrepo/$Ref/prayer-speaker"
$Dir  = Join-Path $env:USERPROFILE 'PrayerSpeaker'
$Audio = Join-Path $Dir 'audio'
function Say($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }

Say '1/7 Stopping any copy that is already running'
Get-CimInstance Win32_Process -Filter "name='pythonw.exe' or name='python.exe'" |
  Where-Object { $_.CommandLine -match 'prayer_cast' } |
  ForEach-Object { Invoke-CimMethod -InputObject $_ -MethodName Terminate | Out-Null }

Say '2/7 Downloading the program'
New-Item -ItemType Directory -Force -Path $Dir, $Audio | Out-Null
Invoke-WebRequest "$Base/prayer_cast.py" -OutFile (Join-Path $Dir 'prayer_cast.py') -UseBasicParsing

Say '3/7 Checking Python'
$py = Get-Command py -ErrorAction SilentlyContinue
if (-not $py) {
  Write-Host 'Installing Python (a window may ask for permission)...'
  winget install -e --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements
  $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
  $py = Get-Command py -ErrorAction SilentlyContinue
  if (-not $py) { throw 'Python was installed but is not found yet. Close PowerShell, open it again and run this line again.' }
}
& py -3 -m pip install --quiet --upgrade pychromecast==14.0.7
$pythonw = (& py -3 -c "import sys,os;print(os.path.join(os.path.dirname(sys.executable),'pythonw.exe'))").Trim()

Say '4/7 Your settings'
$cfgPath = Join-Path $Dir 'config.json'
$old = if (Test-Path $cfgPath) { Get-Content $cfgPath -Raw | ConvertFrom-Json } else { $null }
$city = Read-Host "City for prayer times$(if ($old) { " [$($old.city)]" } else { ' (for example Bengaluru)' })"
if (-not $city -and $old) { $city = $old.city }
$country = Read-Host "Country [$(if ($old) { $old.country } else { 'India' })]"
if (-not $country) { $country = if ($old) { $old.country } else { 'India' } }
$asr = Read-Host 'Asr timing: 1 = Hanafi (common in India), 0 = Shafi''i  [1]'
$school = if ($asr -eq '0') { 0 } else { 1 }
$rem = Read-Host 'Spoken reminder how many minutes before each prayer? (0 = none) [10]'
$reminder = if ($rem -match '^\d+$') { [int]$rem } else { 10 }

Write-Host "`nLooking for speakers on this Wi-Fi..."
@{ city = $city; country = $country; speaker = 'x' } | ConvertTo-Json | Set-Content $cfgPath -Encoding UTF8
& py -3 (Join-Path $Dir 'prayer_cast.py') --list
$default = if ($old) { $old.speaker } else { '' }
$speaker = Read-Host "Type the speaker name exactly as shown above$(if ($default) { " [$default]" })"
if (-not $speaker) { $speaker = $default }

[ordered]@{
  city = $city; country = $country; method = 1; school = $school
  speaker = $speaker; volume = 0.6; reminder_minutes = $reminder
  prayers = @('Fajr','Dhuhr','Asr','Maghrib','Isha'); http_port = 8765
} | ConvertTo-Json | Set-Content $cfgPath -Encoding UTF8

Say '5/7 Making the spoken announcements'
Add-Type -AssemblyName System.Speech
$tts = New-Object System.Speech.Synthesis.SpeechSynthesizer
foreach ($p in 'Fajr','Dhuhr','Asr','Maghrib','Isha') {
  $tts.SetOutputToWaveFile((Join-Path $Audio "say_$($p.ToLower()).wav"));    $tts.Speak("It is time for $p prayer.")
  $tts.SetOutputToWaveFile((Join-Path $Audio "remind_$($p.ToLower()).wav")); $tts.Speak("$p prayer in $reminder minutes.")
}
$tts.SetOutputToNull(); $tts.Dispose()
if (-not (Test-Path (Join-Path $Audio 'azan.mp3'))) {
  Write-Host 'No azan.mp3 yet: the speaker will SAY "It is time for ... prayer" instead.' -ForegroundColor Yellow
  Write-Host "To play a real azan, copy an MP3 into $Audio and name it azan.mp3 (and fajr_azan.mp3 for Fajr, optional)."
  Start-Process explorer.exe $Audio
}

Say '6/7 Starting automatically at log-on'
$lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'PrayerSpeaker.lnk'
$sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$sc.TargetPath = $pythonw; $sc.Arguments = "`"$(Join-Path $Dir 'prayer_cast.py')`""; $sc.WorkingDirectory = $Dir; $sc.Save()
try {
  New-NetFirewallRule -DisplayName 'PrayerSpeaker audio' -Direction Inbound -Protocol TCP -LocalPort 8765 -Profile Private -Action Allow -ErrorAction Stop | Out-Null
} catch { Write-Host 'If Windows asks whether Python may use the network, tick Private networks and click Allow.' -ForegroundColor Yellow }
$ans = Read-Host 'Keep the laptop from sleeping while plugged in, so no prayer is missed? [Y/n]'
if ($ans -notmatch '^[Nn]') { powercfg /change standby-timeout-ac 0; Write-Host 'Sleep while plugged in: never.' }
Start-Process $pythonw -ArgumentList "`"$(Join-Path $Dir 'prayer_cast.py')`"" -WorkingDirectory $Dir -WindowStyle Hidden

Say '7/7 Test'
& py -3 (Join-Path $Dir 'prayer_cast.py') --today
$t = Read-Host 'Play a test announcement on the speaker now? [Y/n]'
if ($t -notmatch '^[Nn]') { & py -3 (Join-Path $Dir 'prayer_cast.py') --test }
Say "ALL DONE. Settings: $cfgPath   Log: $(Join-Path $Dir 'prayer.log')"
