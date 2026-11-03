// Unit tests for the pure JavaScript helpers (no Qt needed):
//   node tests/run.mjs        (or: tests/run.sh)
// Each helper file is a `.pragma library` QML script; it is loaded here by
// stripping the pragma and evaluating it in a fresh scope.
import { readFileSync } from "node:fs"
import { fileURLToPath } from "node:url"
import { dirname, join } from "node:path"
import assert from "node:assert/strict"

const root = join(dirname(fileURLToPath(import.meta.url)), "..")

function load(rel, names) {
    const src = readFileSync(join(root, rel), "utf8").replace(/^\.pragma library/m, "")
    return new Function(`${src}\nreturn { ${names.join(", ")} }`)()
}

let passed = 0, failed = 0
function test(name, fn) {
    try { fn(); passed++; console.log("  ok   " + name) }
    catch (e) { failed++; console.log("  FAIL " + name + "\n       " + String(e.message).split("\n").join("\n       ")) }
}

// ── CalendarLogic ──
const C = load("common/CalendarLogic.js", ["makeKey", "keyOf", "daysBetween", "isoWeek", "weekNumbers",
    "solarToLunar", "dayInfo", "dayOfYear", "daysInYear", "describeRange", "lunarLabel"])

console.log("CalendarLogic")
test("Tet 2020-2028 is lunar 1/1", () => {
    const tet = [[2020, 1, 25], [2021, 2, 12], [2022, 2, 1], [2023, 1, 22], [2024, 2, 10],
                 [2025, 1, 29], [2026, 2, 17], [2027, 2, 6], [2028, 1, 26]]
    for (const [y, m, d] of tet) assert.deepEqual(C.solarToLunar(d, m, y).slice(0, 2), [1, 1], `${y}`)
})
test("leap month 2025 (nhuan 6)", () => {
    const l = C.solarToLunar(25, 7, 2025)   // inside lunar leap month 6
    assert.equal(l[3], 1)
    assert.equal(l[1], 6)
})
test("Gio To Hung Vuong 2026-04-26", () => {
    assert.equal(C.dayInfo(C.makeKey(2026, 4, 26)).holiday.name, "Giỗ Tổ Hùng Vương")
})
test("Giao thua the day before Tet", () => {
    assert.equal(C.dayInfo(C.makeKey(2026, 2, 16)).holiday.name, "Giao thừa")
})
test("fixed holidays", () => {
    assert.equal(C.dayInfo(C.makeKey(2026, 9, 2)).holiday.kind, "holiday")
    assert.equal(C.dayInfo(C.makeKey(2026, 3, 8)).holiday.kind, "obs")
    assert.equal(C.dayInfo(C.makeKey(2026, 10, 21)).holiday, null)
})
test("ISO week edge cases", () => {
    assert.equal(C.isoWeek(20201231), 53)
    assert.equal(C.isoWeek(20210103), 53)
    assert.equal(C.isoWeek(20210104), 1)
    assert.equal(C.isoWeek(20261021), 43)
})
test("weekNumbers gives 6 rows", () => {
    const w = C.weekNumbers(2026, 9)
    assert.equal(w.length, 6)
    assert.equal(w[0], 40)
})
test("day counts", () => {
    assert.equal(C.daysBetween(20261021, 20261102), 12)
    assert.equal(C.dayOfYear(20261021), 294)
    assert.equal(C.daysInYear(2024), 366)
})
test("range text", () => {
    assert.equal(C.describeRange(20261021, 20261102),
        "Wed 21 Oct → Mon 2 Nov 2026 · 12 days apart · 13 inclusive")
})
test("lunar label shows d/m on the first", () => {
    assert.equal(C.lunarLabel(20261010), "1/9")
})

// ── WeatherLogic ──
const W = load("weather/WeatherLogic.js", ["temp", "tempUnit", "wind", "aqi", "uv", "kindKey", "rainKey", "dayName", "clock"])

console.log("WeatherLogic")
test("temperature conversion", () => {
    assert.equal(W.temp(31.4, false), "31")
    assert.equal(W.temp(0, true), "32")
    assert.equal(W.temp(null, false), "--")
    assert.equal(W.tempUnit(true), "°F")
})
test("wind units", () => {
    assert.equal(W.wind(10, false), "10 km/h")
    assert.equal(W.wind(10, true), "6 mph")
})
test("AQI bands", () => {
    assert.equal(W.aqi(40).key, "green")
    assert.equal(W.aqi(103).label, "Unhealthy for sensitive groups")
    assert.equal(W.aqi(null).label, "")
    assert.equal(W.aqi(400).key, "maroon")
})
test("UV bands", () => {
    assert.equal(W.uv(2.9).label, "Low")
    assert.equal(W.uv(7.3).label, "High")
    assert.equal(W.uv(12).label, "Extreme")
})
test("icon colours by kind", () => {
    assert.equal(W.kindKey("clear", true), "yellow")
    assert.equal(W.kindKey("clear", false), "lavender")
    assert.equal(W.kindKey("nope", true), "subtext0")
})
test("rain colours and day names", () => {
    assert.equal(W.rainKey(70), "blue")
    assert.equal(W.rainKey(5), "overlay0")
    assert.equal(W.dayName("2026-10-21", 0), "Today")
    assert.equal(W.dayName("2026-10-22", 1), "Thu")
})
test("clock formatting", () => {
    assert.equal(W.clock(0), "")
    assert.match(W.clock(1792558004), /^\d\d:\d\d$/)
})

// ── LauncherLogic ──
const L = load("launcher/LauncherLogic.js", ["fold", "calc", "formatNumber", "isUrl", "parseXdgExec"])

console.log("LauncherLogic")
test("fold strips accents and lower-cases", () => {
    assert.equal(L.fold("Đường Cà Phê"), "duong ca phe")
    assert.equal(L.fold("Firefox").length, "Firefox".length)
})
test("calculator", () => {
    assert.equal(L.calc("(12+8)*3"), 60)
    assert.equal(L.calc("2^10"), 1024)
    assert.equal(L.calc("2**3"), 8)
    assert.equal(L.calc("10 % 4"), 2)
    assert.equal(L.calc("-3 + 5"), 2)
    assert.equal(L.calc("sqrt(16) + abs(-2)"), 6)
    assert.ok(Math.abs(L.calc("pi") - Math.PI) < 1e-12)
    assert.equal(L.calc("1,5 * 2"), 3)
    assert.equal(L.calc("-2^2"), -4)
    assert.equal(L.calc("2^3^2"), 512)
    assert.equal(L.calc("2^-1"), 0.5)
    assert.equal(L.calc("2*-3"), -6)
})
test("calculator rejects garbage", () => {
    assert.equal(L.calc("1 +"), null)
    assert.equal(L.calc("foo(2)"), null)
    assert.equal(L.calc("1/0"), null)
    assert.equal(L.calc("2 3"), null)
    assert.equal(L.calc("process.exit()"), null)
    assert.equal(L.calc("hasOwnProperty(1)"), null)
    assert.equal(L.calc("constructor(5)"), null)
})
test("number formatting trims float noise", () => {
    assert.equal(L.formatNumber(0.1 + 0.2), "0.3")
    assert.equal(L.formatNumber(60), "60")
})
test("url detection", () => {
    assert.equal(L.isUrl("https://example.com/a?b=1"), true)
    assert.equal(L.isUrl("example.com"), true)
    assert.equal(L.isUrl("firefox"), false)
    assert.equal(L.isUrl("two words.com"), false)
})
test("Exec= parsing", () => {
    assert.deepEqual(L.parseXdgExec("firefox %u", { name: "Firefox" }), ["firefox"])
    assert.deepEqual(L.parseXdgExec('sh -c "echo hi there"', {}), ["sh", "-c", "echo hi there"])
    assert.deepEqual(L.parseXdgExec("env A=1 app --name=%c", { name: "My App" }), ["env", "A=1", "app", "--name=My App"])
    assert.deepEqual(L.parseXdgExec("app 100%% %f", {}), ["app", "100%"])
    assert.deepEqual(L.parseXdgExec("", {}), [])
})

// ── TodoLogic ──
const T = load("todo/TodoLogic.js", ["dueMinutes", "isOverdue", "dueNow", "sortTodos", "markedKeys",
    "addDays", "parseDue", "resolveDue", "normalizeTitle", "formatDue"])
const td = o => ({ id: 1, title: "t", done: 0, due_key: null, due_minutes: null, notified: 0,
                   created_at: 100, done_at: null, ...o })

console.log("TodoLogic")
test("date-only todo is due at 09:00", () => {
    assert.equal(T.dueMinutes(td({ due_key: 20261105 })), 540)
    assert.equal(T.dueMinutes(td({ due_key: 20261105, due_minutes: 600 })), 600)
})
test("isOverdue boundary and exclusions", () => {
    const t = td({ due_key: 20261105, due_minutes: 600 })
    assert.equal(T.isOverdue(t, 20261105, 600), false)
    assert.equal(T.isOverdue(t, 20261105, 601), true)
    assert.equal(T.isOverdue(td({ ...t, done: 1 }), 20261106, 0), false)
    assert.equal(T.isOverdue(td(), 20261106, 0), false)
})
test("dueNow: boundary, notified, done, late-added date-only", () => {
    const t = td({ id: 1, due_key: 20261105, due_minutes: 600 })
    assert.deepEqual(T.dueNow([t], 20261105, 599).map(x => x.id), [])
    assert.deepEqual(T.dueNow([t], 20261105, 600).map(x => x.id), [1])
    assert.deepEqual(T.dueNow([td({ ...t, notified: 1 })], 20261105, 700), [])
    assert.deepEqual(T.dueNow([td({ ...t, done: 1 })], 20261105, 700), [])
    const dateOnly = td({ id: 2, due_key: 20261105 })
    assert.deepEqual(T.dueNow([dateOnly], 20261105, 539), [])
    assert.deepEqual(T.dueNow([dateOnly], 20261105, 1020).map(x => x.id), [2])   // added at 17:00
})
test("sortTodos order", () => {
    const list = [
        td({ id: 1 }),                                                  // undated
        td({ id: 2, done: 1, done_at: 50 }),
        td({ id: 3, due_key: 20261105, due_minutes: 900 }),             // later today
        td({ id: 4, due_key: 20261101 }),                               // overdue
        td({ id: 5, done: 1, done_at: 80 }),
    ]
    assert.deepEqual(T.sortTodos(list, 20261105, 600).map(x => x.id), [4, 3, 1, 5, 2])
})
test("markedKeys: open dated only, unique, sorted", () => {
    const list = [td({ due_key: 20261105 }), td({ due_key: 20261105 }), td({ due_key: 20261101, done: 1 }),
                  td({ due_key: 20261103 }), td()]
    assert.deepEqual(T.markedKeys(list), [20261103, 20261105])
})
test("addDays crosses month/year and leap day", () => {
    assert.equal(T.addDays(20261231, 1), 20270101)
    assert.equal(T.addDays(20240228, 1), 20240229)
    assert.equal(T.addDays(20261105, 7), 20261112)
    assert.equal(T.addDays(20261101, -1), 20261031)
})
test("parseDue", () => {
    assert.deepEqual(T.parseDue("05/11", 20261103), { key: 20261105, minutes: null })
    assert.deepEqual(T.parseDue(" 05/11 14:30 ", 20261103), { key: 20261105, minutes: 870 })
    assert.deepEqual(T.parseDue("05/11 9:05", 20261103), { key: 20261105, minutes: 545 })
    assert.equal(T.parseDue("03/11", 20261103).key, 20261103)           // today counts
    assert.equal(T.parseDue("02/11", 20261103).key, 20271102)           // passed -> next year
    assert.equal(T.parseDue("29/02", 20261103).key, 20280229)           // next leap year
    assert.equal(T.parseDue("05/11/2027", 20261103).key, 20271105)
    for (const bad of ["", "abc", "31/02", "32/01", "05/13", "05/11 25:00", "05/11 10:60"])
        assert.equal(T.parseDue(bad, 20261103), null, bad)
})
test("resolveDue: chips, typed override, invalid", () => {
    const t = 20261231
    assert.deepEqual(T.resolveDue("", "", t), { ok: true, key: null, minutes: null })
    assert.deepEqual(T.resolveDue("today", "", t), { ok: true, key: 20261231, minutes: null })
    assert.deepEqual(T.resolveDue("tomorrow", "", t), { ok: true, key: 20270101, minutes: null })
    assert.deepEqual(T.resolveDue("week", "", t), { ok: true, key: 20270107, minutes: null })
    assert.deepEqual(T.resolveDue("today", "05/01 10:00", t), { ok: true, key: 20270105, minutes: 600 })
    assert.equal(T.resolveDue("", "garbage", t).ok, false)
})
test("normalizeTitle", () => {
    assert.equal(T.normalizeTitle("  hello   world \n"), "hello world")
    assert.equal(T.normalizeTitle("line1\nline2"), "line1 line2")
    assert.equal(T.normalizeTitle("   \n "), "")
    assert.equal(T.normalizeTitle("a".repeat(300)).length, 200)
})
test("formatDue", () => {
    assert.equal(T.formatDue(td(), 20261105), "")
    assert.equal(T.formatDue(td({ due_key: 20261105 }), 20261105), "Today")
    assert.equal(T.formatDue(td({ due_key: 20261105, due_minutes: 870 }), 20261105), "Today 14:30")
    assert.equal(T.formatDue(td({ due_key: 20261106 }), 20261105), "Tomorrow")
    assert.equal(T.formatDue(td({ due_key: 20261112 }), 20261105), "12/11")
    assert.equal(T.formatDue(td({ due_key: 20261105 }), 0), "05/11 09:00")
})

console.log(`\n${passed} passed, ${failed} failed`)
process.exit(failed ? 1 : 0)
