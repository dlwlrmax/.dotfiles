.pragma library

// Pure helpers for the todo module: due-time maths, ordering, input parsing and
// display formatting. Self-contained (no imports) so tests/run.mjs can eval it.
//
// A todo is {id, title, content, done: 0|1, due_key: yyyymmdd|null, due_minutes: 0..1439|null,
//            notified: 0|1, created_at, done_at}. A date-only todo is due at 09:00.

var DEFAULT_DUE_MINUTES = 540
var MAX_TITLE = 200
var MAX_CONTENT = 4000

function pad2(n) { return (n < 10 ? "0" : "") + n }

function dueMinutes(todo) {
    return todo.due_minutes === null || todo.due_minutes === undefined
        ? DEFAULT_DUE_MINUTES : todo.due_minutes
}

// Single comparable number: day index * 1440 + minutes of day.
function dueStamp(todo) { return todo.due_key * 1440 + dueMinutes(todo) }

function isDated(todo) { return todo.due_key !== null && todo.due_key !== undefined }

function isOpenDated(todo) { return !todo.done && isDated(todo) }

function isOverdue(todo, nowKey, nowMinutes) {
    return isOpenDated(todo) && dueStamp(todo) < nowKey * 1440 + nowMinutes
}

function dueNow(todos, nowKey, nowMinutes) {
    var now = nowKey * 1440 + nowMinutes
    return todos.filter(function (t) {
        return isOpenDated(t) && !t.notified && dueStamp(t) <= now
    })
}

function sortTodos(todos, nowKey, nowMinutes) {
    var now = nowKey * 1440 + nowMinutes
    function rank(t) {
        if (t.done) return 3
        if (!isDated(t)) return 2
        return dueStamp(t) < now ? 0 : 1
    }
    return todos.slice().sort(function (a, b) {
        var ra = rank(a), rb = rank(b)
        if (ra !== rb) return ra - rb
        if (ra === 3) return (b.done_at || 0) - (a.done_at || 0)
        if (ra <= 1) {
            var d = dueStamp(a) - dueStamp(b)
            if (d !== 0) return d
        }
        return (a.created_at || 0) - (b.created_at || 0)
    })
}

function markedKeys(todos) {
    var seen = {}, out = []
    todos.forEach(function (t) {
        if (isOpenDated(t) && !seen[t.due_key]) { seen[t.due_key] = true; out.push(t.due_key) }
    })
    return out.sort(function (a, b) { return a - b })
}

function keyToUtc(key) {
    return Date.UTC(Math.floor(key / 10000), Math.floor(key / 100) % 100 - 1, key % 100)
}

function addDays(key, n) {
    var d = new Date(keyToUtc(key) + n * 86400000)
    return d.getUTCFullYear() * 10000 + (d.getUTCMonth() + 1) * 100 + d.getUTCDate()
}

// True if y-m-d is a real calendar date (rejects 31/02, 29/02 in non-leap years).
function validDate(y, m, d) {
    var dt = new Date(Date.UTC(y, m - 1, d))
    return dt.getUTCFullYear() === y && dt.getUTCMonth() === m - 1 && dt.getUTCDate() === d
}

// "dd/mm[/yyyy] [h:mm]" -> {key, minutes|null} or null. Without a year, picks the
// first occurrence on or after todayKey (this year, else next; scans for 29/02).
function parseDue(text, todayKey) {
    var m = /^(\d{1,2})\/(\d{1,2})(?:\/(\d{4}))?(?:\s+(\d{1,2}):(\d{2}))?$/.exec(String(text).trim())
    if (!m) return null
    var d = parseInt(m[1], 10), mo = parseInt(m[2], 10)
    var minutes = null
    if (m[4] !== undefined) {
        var h = parseInt(m[4], 10), mi = parseInt(m[5], 10)
        if (h > 23 || mi > 59) return null
        minutes = h * 60 + mi
    }
    if (m[3] !== undefined) {
        var yy = parseInt(m[3], 10)
        return validDate(yy, mo, d) ? { key: yy * 10000 + mo * 100 + d, minutes: minutes } : null
    }
    var y0 = Math.floor(todayKey / 10000)
    for (var y = y0; y <= y0 + 8; y++) {
        if (!validDate(y, mo, d)) continue
        var key = y * 10000 + mo * 100 + d
        if (key >= todayKey) return { key: key, minutes: minutes }
    }
    return null
}

function resolveDue(chip, typed, todayKey) {
    var text = String(typed || "").trim()
    if (text !== "") {
        var p = parseDue(text, todayKey)
        return p ? { ok: true, key: p.key, minutes: p.minutes }
                 : { ok: false, key: null, minutes: null }
    }
    var n = chip === "today" ? 0 : chip === "tomorrow" ? 1 : chip === "week" ? 7 : -1
    return { ok: true, key: n < 0 ? null : addDays(todayKey, n), minutes: null }
}

// Optional time of day for the add bar: "" -> no time; "h:mm" / "hh:mm" -> minutes after midnight.
function parseTime(text) {
    var s = String(text || "").trim()
    if (s === "") return { ok: true, minutes: null }
    var m = /^(\d{1,2}):(\d{2})$/.exec(s)
    if (!m) return { ok: false, minutes: null }
    var h = parseInt(m[1], 10), mi = parseInt(m[2], 10)
    if (h > 23 || mi > 59) return { ok: false, minutes: null }
    return { ok: true, minutes: h * 60 + mi }
}

function normalizeTitle(s) {
    return String(s).replace(/\s+/g, " ").trim().slice(0, MAX_TITLE)
}

// Multi-line note: normalise line endings, trim blank edges, cap length.
function normalizeContent(s) {
    return String(s === null || s === undefined ? "" : s)
        .replace(/\r\n?/g, "\n").replace(/[ \t]+\n/g, "\n").trim().slice(0, MAX_CONTENT)
}

function formatDue(todo, todayKey) {
    if (!isDated(todo)) return ""
    var k = todo.due_key
    var hasTime = todo.due_minutes !== null && todo.due_minutes !== undefined
    var time = function (min) { return pad2(Math.floor(min / 60)) + ":" + pad2(min % 60) }
    if (todayKey === 0) return pad2(k % 100) + "/" + pad2(Math.floor(k / 100) % 100) + " " + time(dueMinutes(todo))
    var day = k === todayKey ? "Today"
            : k === addDays(todayKey, 1) ? "Tomorrow"
            : pad2(k % 100) + "/" + pad2(Math.floor(k / 100) % 100)
    return hasTime ? day + " " + time(todo.due_minutes) : day
}
