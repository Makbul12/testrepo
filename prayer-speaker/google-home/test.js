const { build, hhmm, addDays } = require("./build.js");
const assert = require("assert");
function month(y, m, n, f) {
  return Array.from({ length: n }, (_, i) => ({
    date: { gregorian: { date: `${String(i + 1).padStart(2, "0")}-${String(m).padStart(2, "0")}-${y}` } },
    timings: { Fajr: hhmm(300 + f(i)) + " (IST)", Dhuhr: "12:10 (IST)", Asr: "15:30 (IST)", Maghrib: hhmm(1075 - f(i)) + " (IST)", Isha: "19:05 (IST)" },
  }));
}
const nov = month(2026, 11, 30, (i) => Math.floor(i / 3)), dec = month(2026, 12, 31, (i) => 10 + Math.floor(i / 3));
assert.equal(addDays("2026-11-25", 10), "2026-12-05");
const r = build([nov, dec], { city: "Bengaluru", speaker: "Nest Mini - Bedroom", reminder_minutes: 10, days: 15 }, "2026-11-25");
console.log(r.yaml); console.log(r.summary.join("\n"), "\nuntil", r.until);
const fajrs = [...nov.slice(24), ...dec.slice(0, 9)].map((d) => d.timings.Fajr.slice(0, 5)).sort();
assert.ok(r.yaml.includes("at: " + fajrs[fajrs.length - 1]));
assert.ok(r.yaml.includes("at: " + hhmm(parseInt(fajrs[0]) * 60 + parseInt(fajrs[0].slice(3)) - 10)));
assert.equal((r.yaml.match(/type: time.schedule/g) || []).length, 10);
const r2 = build([nov], { city: "X", reminder_minutes: 0 }, "2026-11-01");
assert.ok(!r2.yaml.includes("devices:") && (r2.yaml.match(/time.schedule/g) || []).length === 5);
console.log("ALL TESTS PASSED");
