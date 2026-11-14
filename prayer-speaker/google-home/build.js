// Builds a Google Home script-editor automation from Aladhan prayer times.
// Runs on macOS with:  osascript -l JavaScript build.js <config.json> <month1.json> [month2.json]
// The pure functions below are also loaded by test.js under Node.

var PRAYERS = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];

function minutes(hhmm) {            // "05:02 (IST)" -> 302
  var m = /(\d{1,2}):(\d{2})/.exec(hhmm);
  return parseInt(m[1], 10) * 60 + parseInt(m[2], 10);
}
function hhmm(min) {
  min = ((min % 1440) + 1440) % 1440;
  var h = Math.floor(min / 60), m = min % 60;
  return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
}
function isoOf(ddmmyyyy) {         // "14-11-2026" -> "2026-11-14"
  var p = ddmmyyyy.split("-");
  return p[2] + "-" + p[1] + "-" + p[0];
}
function addDays(iso, n) {
  var d = new Date(iso + "T12:00:00Z");
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}
function pretty(iso) {
  var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
  var p = iso.split("-");
  return parseInt(p[2], 10) + " " + months[parseInt(p[1], 10) - 1] + " " + p[0];
}
function yamlStr(s) { return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"'; }

// months: arrays of Aladhan "data" days. Returns {yaml, summary, until}.
function build(months, cfg, todayIso) {
  var days = cfg.days || 15;
  var last = addDays(todayIso, days - 1);
  var range = {};
  PRAYERS.forEach(function (p) { range[p] = { min: 1e9, max: -1 }; });
  var count = 0;
  months.forEach(function (month) {
    month.forEach(function (day) {
      var iso = isoOf(day.date.gregorian.date);
      if (iso < todayIso || iso > last) return;
      count++;
      PRAYERS.forEach(function (p) {
        var t = minutes(day.timings[p]);
        range[p].min = Math.min(range[p].min, t);
        range[p].max = Math.max(range[p].max, t);
      });
    });
  });
  if (count === 0) throw new Error("no prayer times found for " + todayIso);

  var out = [];
  out.push("metadata:");
  out.push("  name: " + yamlStr("Prayer times " + cfg.city + " (" + pretty(todayIso) + " - " + pretty(last) + ")"));
  out.push("  description: " + yamlStr("Generated from aladhan.com. Times are the latest of the period, so the call is never early. Run the Mac command again after " + pretty(last) + "."));
  out.push("");
  out.push("automations:");
  var summary = [];
  function add(at, message) {
    out.push("  - starters:");
    out.push("      - type: time.schedule");
    out.push("        at: " + at);
    out.push("    actions:");
    out.push("      - type: assistant.command.Broadcast");
    out.push("        message: " + yamlStr(message));
    if (cfg.speaker) out.push("        devices: " + yamlStr(cfg.speaker));
  }
  (cfg.prayers || PRAYERS).forEach(function (p) {
    var r = range[p];
    var rem = parseInt(cfg.reminder_minutes || 0, 10);
    if (rem > 0) add(hhmm(r.min - rem), p + " prayer in " + rem + " minutes.");
    add(hhmm(r.max), "It is time for " + p + " prayer.");
    summary.push(p + ": " + hhmm(r.max) + (r.min !== r.max ? "  (actual " + hhmm(r.min) + " to " + hhmm(r.max) + ")" : ""));
  });
  return { yaml: out.join("\n") + "\n", summary: summary, until: last };
}

// ---- macOS entry point (JavaScript for Automation) ----
function readFile(path) {
  return $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null).js;
}
function run(argv) {
  ObjC.import("Foundation");
  var cfg = JSON.parse(readFile(argv[0]));
  var months = argv.slice(1).map(function (p) { return JSON.parse(readFile(p)).data; });
  var now = new Date();
  var todayIso = now.getFullYear() + "-" + ("0" + (now.getMonth() + 1)).slice(-2) + "-" + ("0" + now.getDate()).slice(-2);
  var r = build(months, cfg, todayIso);
  return r.yaml + "\n#SUMMARY#\n" + r.summary.join("\n") + "\n#UNTIL#" + pretty(r.until);
}

if (typeof module !== "undefined") module.exports = { build: build, minutes: minutes, hhmm: hhmm, addDays: addDays };
