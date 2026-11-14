"""Prayer-time announcements on a Google Nest / Home speaker.

Runs in the background on a Windows laptop (started by Task Scheduler at log-on). Each month it
downloads the prayer times for your city from the free Aladhan API (https://aladhan.com) and keeps a
copy, so a day without internet still works. At each prayer it finds the speaker on the Wi-Fi by its
NAME (not its IP address, which the router can change), raises the volume, plays the azan, then
puts the volume back.

  python prayer_cast.py            run forever (what Task Scheduler starts)
  python prayer_cast.py --list     show the speakers found on this Wi-Fi
  python prayer_cast.py --today    show today's times and what will play
  python prayer_cast.py --test     play the Dhuhr azan on the speaker now
"""
import datetime as dt
import functools
import http.server
import json
import logging
import re
import socket
import sys
import threading
import time
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
AUDIO = HERE / "audio"
CACHE = HERE / "cache"
PRAYERS = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.FileHandler(HERE / "prayer.log", encoding="utf-8"), logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger("prayer")


def load_config():
    cfg = json.loads((HERE / "config.json").read_text(encoding="utf-8"))
    cfg.setdefault("method", 1)          # 1 = University of Islamic Sciences, Karachi (common in India)
    cfg.setdefault("school", 1)          # 1 = Hanafi Asr, 0 = Shafi'i
    cfg.setdefault("volume", 0.6)        # 0.0 to 1.0 while the azan plays
    cfg.setdefault("reminder_minutes", 10)
    cfg.setdefault("prayers", PRAYERS)
    cfg.setdefault("http_port", 8765)
    return cfg


# ---------- prayer times ----------

def month_times(cfg, year, month):
    """{date: {prayer: datetime}} for a month, from the cache or the Aladhan API."""
    CACHE.mkdir(exist_ok=True)
    key = re.sub(r"[^A-Za-z0-9]+", "_", f"{cfg['city']}_{cfg['country']}_{cfg['method']}_{cfg['school']}")
    path = CACHE / f"{key}_{year}_{month:02d}.json"
    data = None
    if path.exists():
        data = json.loads(path.read_text(encoding="utf-8"))
    else:
        q = urllib.parse.urlencode({"city": cfg["city"], "country": cfg["country"],
                                    "method": cfg["method"], "school": cfg["school"]})
        url = f"https://api.aladhan.com/v1/calendarByCity/{year}/{month}?{q}"
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                data = json.load(r)["data"]
            path.write_text(json.dumps(data), encoding="utf-8")
            log.info("downloaded prayer times for %s-%02d", year, month)
        except Exception as e:  # no internet: try again later
            log.warning("could not download prayer times (%s)", e)
            return {}
    out = {}
    for day in data:
        d = dt.datetime.strptime(day["date"]["gregorian"]["date"], "%d-%m-%Y").date()
        out[d] = {}
        for p in PRAYERS:
            m = re.match(r"\s*(\d{1,2}):(\d{2})", day["timings"][p])
            out[d][p] = dt.datetime.combine(d, dt.time(int(m.group(1)), int(m.group(2))))
    return out


def events_for(cfg, day):
    """[(when, prayer, kind)] for one day; kind is 'azan' or 'reminder'."""
    times = month_times(cfg, day.year, day.month).get(day, {})
    ev = []
    for p in cfg["prayers"]:
        if p not in times:
            continue
        ev.append((times[p], p, "azan"))
        if cfg["reminder_minutes"]:
            ev.append((times[p] - dt.timedelta(minutes=cfg["reminder_minutes"]), p, "reminder"))
    return sorted(ev)


# ---------- audio server and speaker ----------

def lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    finally:
        s.close()


class _QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def start_audio_server(port):
    """Serve the audio folder to the speaker. If the port is taken, the background copy already serves it."""
    handler = functools.partial(_QuietHandler, directory=str(AUDIO))
    try:
        srv = http.server.ThreadingHTTPServer(("0.0.0.0", port), handler)
    except OSError:
        log.info("port %s in use: using the audio server that is already running", port)
        return None
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


def audio_file(prayer, kind):
    """The file to play: fajr_azan.mp3 for Fajr if present, else azan.mp3; spoken WAVs for reminders."""
    names = ([f"{prayer.lower()}_azan.mp3", "azan.mp3", f"say_{prayer.lower()}.wav"] if kind == "azan"
             else [f"remind_{prayer.lower()}.wav"])
    for n in names:
        if (AUDIO / n).exists():
            return n
    return None


def play(cfg, filename):
    import pychromecast  # imported here so --today works without it

    name = cfg["speaker"]
    casts, browser = pychromecast.get_listed_chromecasts(friendly_names=[name], discovery_timeout=15)
    try:
        if not casts:
            log.error("speaker '%s' not found on this Wi-Fi (run with --list to see names)", name)
            return False
        cast = casts[0]
        cast.wait(timeout=20)
        old = cast.status.volume_level if cast.status else None
        cast.set_volume(float(cfg["volume"]))
        url = f"http://{lan_ip()}:{cfg['http_port']}/{urllib.parse.quote(filename)}"
        ctype = "audio/wav" if filename.endswith(".wav") else "audio/mpeg"
        mc = cast.media_controller
        mc.play_media(url, ctype, title="Prayer time", stream_type="BUFFERED")
        mc.block_until_active(timeout=20)
        log.info("playing %s on %s", filename, name)
        # Wait for the end (at most 6 minutes), then put the volume back.
        start = time.time()
        seen_playing = False
        while time.time() - start < 360:
            time.sleep(2)
            state = mc.status.player_state
            if state in ("PLAYING", "BUFFERING"):
                seen_playing = True
            elif seen_playing and state == "IDLE":
                break
        if old is not None:
            cast.set_volume(old)
        return True
    except Exception:
        log.exception("could not play on the speaker")
        return False
    finally:
        pychromecast.discovery.stop_discovery(browser)


# ---------- main loop ----------

def run(cfg):
    start_audio_server(cfg["http_port"])
    log.info("started: %s, %s; speaker '%s'", cfg["city"], cfg["country"], cfg["speaker"])
    done = set()
    while True:
        now = dt.datetime.now()
        upcoming = [e for d in (now.date(), now.date() + dt.timedelta(days=1)) for e in events_for(cfg, d)]
        for when, prayer, kind in upcoming:
            key = (when, prayer, kind)
            # Fire within 2 minutes after the time. If the laptop was asleep longer, skip it.
            if key not in done and when <= now <= when + dt.timedelta(minutes=2):
                done.add(key)
                f = audio_file(prayer, kind)
                if f:
                    log.info("%s %s at %s", prayer, kind, when.strftime("%H:%M"))
                    play(cfg, f)
                else:
                    log.warning("no audio file for %s %s", prayer, kind)
        if not upcoming:
            time.sleep(600)  # no times yet (offline): try again in 10 minutes
        else:
            time.sleep(15)


def main():
    cfg = load_config()
    arg = sys.argv[1] if len(sys.argv) > 1 else ""
    if arg == "--list":
        import pychromecast
        casts, browser = pychromecast.get_chromecasts(timeout=15)
        pychromecast.discovery.stop_discovery(browser)
        for c in casts:
            print(f"  {c.cast_info.friendly_name}   ({c.cast_info.model_name}, {c.cast_info.host})")
        if not casts:
            print("  no speakers found. Is the laptop on the same Wi-Fi as the speaker?")
    elif arg == "--today":
        for when, p, kind in events_for(cfg, dt.date.today()):
            print(f"  {when:%H:%M}  {p:8} {kind:9} {audio_file(p, kind) or 'NO AUDIO FILE'}")
    elif arg == "--test":
        srv = start_audio_server(cfg["http_port"])
        f = audio_file("Dhuhr", "azan")
        print("playing", f, "on", cfg["speaker"]) if f else print("no audio file in", AUDIO)
        ok = bool(f) and play(cfg, f)
        if srv:
            srv.shutdown()
        sys.exit(0 if ok else 1)
    else:
        run(cfg)


if __name__ == "__main__":
    main()
