.pragma library

// Date helpers, ISO weeks, Vietnamese lunar calendar (UTC+7) and VN holidays.
// Pure functions only so both the calendar panel and the bar clock can use them.
// Lunar conversion: Ho Ngoc Duc's astronomical algorithm.
//
// A "key" is an integer yyyymmdd (e.g. 20261021); months in keys are 1-based.

var TZ = 7
var WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
var MONTHS_LONG = ["January", "February", "March", "April", "May", "June", "July",
                   "August", "September", "October", "November", "December"]
var CAN = ["Giáp", "Ất", "Bính", "Đinh", "Mậu", "Kỷ", "Canh", "Tân", "Nhâm", "Quý"]
var CHI = ["Tý", "Sửu", "Dần", "Mão", "Thìn", "Tỵ", "Ngọ", "Mùi", "Thân", "Dậu", "Tuất", "Hợi"]

// ── keys ──
function makeKey(y, m1, d) { return y * 10000 + m1 * 100 + d }
function keyOf(date) { return makeKey(date.getFullYear(), date.getMonth() + 1, date.getDate()) }
function keyYear(k) { return Math.floor(k / 10000) }
function keyMonth(k) { return Math.floor(k / 100) % 100 }
function keyDay(k) { return k % 100 }
function keyToDate(k) { return new Date(keyYear(k), keyMonth(k) - 1, keyDay(k)) }

function dayNumber(k) {
    return Math.round(Date.UTC(keyYear(k), keyMonth(k) - 1, keyDay(k)) / 86400000)
}
function daysBetween(a, b) { return dayNumber(b) - dayNumber(a) }

function dayOfYear(k) {
    return daysBetween(makeKey(keyYear(k), 1, 1), k) + 1
}
function daysInYear(y) {
    return daysBetween(makeKey(y, 1, 1), makeKey(y + 1, 1, 1))
}

// ISO-8601 week number of the date with this key.
function isoWeek(k) {
    var t = new Date(Date.UTC(keyYear(k), keyMonth(k) - 1, keyDay(k)))
    var day = t.getUTCDay() || 7
    t.setUTCDate(t.getUTCDate() + 4 - day)
    var y0 = Date.UTC(t.getUTCFullYear(), 0, 1)
    return Math.ceil(((t.getTime() - y0) / 86400000 + 1) / 7)
}

// ISO week numbers for the 6 Monday-first rows MonthGrid shows for (year, month0).
function weekNumbers(year, month0) {
    var first = new Date(year, month0, 1)
    var offset = (first.getDay() + 6) % 7
    var out = []
    for (var i = 0; i < 6; i++)
        out.push(isoWeek(keyOf(new Date(year, month0, 1 - offset + i * 7 + 3))))
    return out
}

// ── lunar calendar ──
function INT(d) { return Math.floor(d) }

function jdFromDate(dd, mm, yy) {
    var a = INT((14 - mm) / 12)
    var y = yy + 4800 - a
    var m = mm + 12 * a - 3
    var jd = dd + INT((153 * m + 2) / 5) + 365 * y + INT(y / 4) - INT(y / 100) + INT(y / 400) - 32045
    if (jd < 2299161)
        jd = dd + INT((153 * m + 2) / 5) + 365 * y + INT(y / 4) - 32083
    return jd
}

function newMoon(k) {
    var T = k / 1236.85, T2 = T * T, T3 = T2 * T, dr = Math.PI / 180
    var Jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * T2 - 0.000000155 * T3
    Jd1 = Jd1 + 0.00033 * Math.sin((166.56 + 132.87 * T - 0.009173 * T2) * dr)
    var M = 359.2242 + 29.10535608 * k - 0.0000333 * T2 - 0.00000347 * T3
    var Mpr = 306.0253 + 385.81691806 * k + 0.0107306 * T2 + 0.00001236 * T3
    var F = 21.2964 + 390.67050646 * k - 0.0016528 * T2 - 0.00000239 * T3
    var C1 = (0.1734 - 0.000393 * T) * Math.sin(M * dr) + 0.0021 * Math.sin(2 * dr * M)
    C1 = C1 - 0.4068 * Math.sin(Mpr * dr) + 0.0161 * Math.sin(dr * 2 * Mpr)
    C1 = C1 - 0.0004 * Math.sin(dr * 3 * Mpr)
    C1 = C1 + 0.0104 * Math.sin(dr * 2 * F) - 0.0051 * Math.sin(dr * (M + Mpr))
    C1 = C1 - 0.0074 * Math.sin(dr * (M - Mpr)) + 0.0004 * Math.sin(dr * (2 * F + M))
    C1 = C1 - 0.0004 * Math.sin(dr * (2 * F - M)) - 0.0006 * Math.sin(dr * (2 * F + Mpr))
    C1 = C1 + 0.0010 * Math.sin(dr * (2 * F - Mpr)) + 0.0005 * Math.sin(dr * (2 * Mpr + M))
    var deltat
    if (T < -11)
        deltat = 0.001 + 0.000839 * T + 0.0002261 * T2 - 0.00000845 * T3 - 0.000000081 * T * T3
    else
        deltat = -0.000278 + 0.000265 * T + 0.000262 * T2
    return Jd1 + C1 - deltat
}

// The astronomy below is the expensive part; memoize it so a whole year of
// conversions costs a handful of evaluations.
var _nm = {}, _m11 = {}, _leap = {}, _lunar = {}

function newMoonDay(k) {
    var v = _nm[k]
    if (v === undefined) v = _nm[k] = INT(newMoon(k) + 0.5 + TZ / 24)
    return v
}

function sunLongitude(jdn) {
    var T = (jdn - 2451545.0) / 36525, T2 = T * T, dr = Math.PI / 180
    var M = 357.52910 + 35999.05030 * T - 0.0001559 * T2 - 0.00000048 * T * T2
    var L0 = 280.46645 + 36000.76983 * T + 0.0003032 * T2
    var DL = (1.914600 - 0.004817 * T - 0.000014 * T2) * Math.sin(dr * M)
    DL = DL + (0.019993 - 0.000101 * T) * Math.sin(2 * dr * M) + 0.000290 * Math.sin(3 * dr * M)
    var L = (L0 + DL) * dr
    return L - Math.PI * 2 * INT(L / (Math.PI * 2))
}

function sunLongitudeSector(day) { return INT(sunLongitude(day - 0.5 - TZ / 24) / Math.PI * 6) }

function lunarMonth11(yy) {
    var c = _m11[yy]
    if (c !== undefined) return c
    var off = jdFromDate(31, 12, yy) - 2415021
    var k = INT(off / 29.530588853)
    var nm = newMoonDay(k)
    if (sunLongitudeSector(nm) >= 9) nm = newMoonDay(k - 1)
    return (_m11[yy] = nm)
}

function leapMonthOffset(a11) {
    var c = _leap[a11]
    if (c !== undefined) return c
    var k = INT((a11 - 2415021.076998695) / 29.530588853 + 0.5)
    var last = 0, i = 1
    var arc = sunLongitudeSector(newMoonDay(k + i))
    do {
        last = arc
        i++
        arc = sunLongitudeSector(newMoonDay(k + i))
    } while (arc !== last && i < 14)
    return (_leap[a11] = i - 1)
}

// [lunarDay, lunarMonth, lunarYear, isLeapMonth]
function solarToLunar(dd, mm, yy) {
    var dayNum = jdFromDate(dd, mm, yy)
    var k = INT((dayNum - 2415021.076998695) / 29.530588853)
    var monthStart = newMoonDay(k + 1)
    if (monthStart > dayNum) monthStart = newMoonDay(k)
    var a11 = lunarMonth11(yy), b11 = a11, lunarYear
    if (a11 >= monthStart) {
        lunarYear = yy
        a11 = lunarMonth11(yy - 1)
    } else {
        lunarYear = yy + 1
        b11 = lunarMonth11(yy + 1)
    }
    var lunarDay = dayNum - monthStart + 1
    var diff = INT((monthStart - a11) / 29)
    var leap = 0
    var lunarMonth = diff + 11
    if (b11 - a11 > 365) {
        var leapDiff = leapMonthOffset(a11)
        if (diff >= leapDiff) {
            lunarMonth = diff + 10
            if (diff === leapDiff) leap = 1
        }
    }
    if (lunarMonth > 12) lunarMonth -= 12
    if (lunarMonth >= 11 && diff < 4) lunarYear -= 1
    return [lunarDay, lunarMonth, lunarYear, leap]
}

function yearName(lunarYear) {
    return CAN[(lunarYear + 6) % 10] + " " + CHI[(lunarYear + 8) % 12]
}

// ── holidays ──
// Fixed public holidays and notable observances. Substitute days off that the
// government announces per year are intentionally not modelled.
var SOLAR_HOLIDAYS = {
    "1/1": "Tết Dương lịch", "30/4": "Giải phóng miền Nam",
    "1/5": "Quốc tế Lao động", "2/9": "Quốc khánh"
}
var SOLAR_OBS = {
    "8/3": "Quốc tế Phụ nữ", "1/6": "Quốc tế Thiếu nhi", "20/10": "Phụ nữ Việt Nam",
    "20/11": "Nhà giáo Việt Nam", "24/12": "Đêm Giáng sinh", "25/12": "Giáng sinh"
}
var LUNAR_OBS = {
    "15/1": "Tết Nguyên Tiêu", "5/5": "Tết Đoan Ngọ", "15/7": "Vu Lan",
    "15/8": "Tết Trung thu", "23/12": "Ông Táo chầu trời"
}

var _cache = {}

function lunarOf(k) {
    var l = _lunar[k]
    if (!l) l = _lunar[k] = solarToLunar(keyDay(k), keyMonth(k), keyYear(k))
    return l
}

// { lunar: [d, m, y, leap], holiday: {name, kind: "holiday"|"obs"} | null }
function dayInfo(k) {
    var hit = _cache[k]
    if (hit) return hit

    var y = keyYear(k), m = keyMonth(k), d = keyDay(k)
    var lunar = lunarOf(k)
    var ld = lunar[0], lm = lunar[1], leap = lunar[3]
    var holiday = null

    var sk = d + "/" + m, lk = ld + "/" + lm
    if (SOLAR_HOLIDAYS[sk]) holiday = { name: SOLAR_HOLIDAYS[sk], kind: "holiday" }

    if (!leap) {
        if (lm === 1 && ld <= 3)
            holiday = { name: "Tết Nguyên Đán (mùng " + ld + ")", kind: "holiday" }
        else if (lk === "10/3")
            holiday = { name: "Giỗ Tổ Hùng Vương", kind: "holiday" }
    }
    if (!holiday) {
        // Giao thừa = the day before lunar 1/1.
        var nl = lunarOf(keyOf(new Date(y, m - 1, d + 1)))
        if (nl[0] === 1 && nl[1] === 1 && !nl[3]) holiday = { name: "Giao thừa", kind: "holiday" }
    }
    if (!holiday && !leap && LUNAR_OBS[lk]) holiday = { name: LUNAR_OBS[lk], kind: "obs" }
    if (!holiday && SOLAR_OBS[sk]) holiday = { name: SOLAR_OBS[sk], kind: "obs" }

    return (_cache[k] = { lunar: lunar, holiday: holiday })
}

// Short lunar label for a cell: "12", or "1/10" on the first of a lunar month.
function lunarLabel(k) {
    var l = dayInfo(k).lunar
    return l[0] === 1 ? "1/" + l[1] + (l[3] ? "n" : "") : String(l[0])
}

function lunarFull(k) {
    var l = dayInfo(k).lunar
    return "Âm " + l[0] + "/" + l[1] + (l[3] ? " nhuận" : "") + " · " + yearName(l[2])
}

// ── text ──
function dateText(k, withYear) {
    var dt = keyToDate(k)
    return WEEKDAYS[dt.getDay()] + " " + keyDay(k) + " " + MONTHS[keyMonth(k) - 1]
        + (withYear === false ? "" : " " + keyYear(k))
}

function relativeText(k, todayKey) {
    var n = daysBetween(todayKey, k)
    if (n === 0) return "today"
    if (n === 1) return "tomorrow"
    if (n === -1) return "yesterday"
    return n > 0 ? "in " + n + " days" : -n + " days ago"
}

// Info line as typed segments so the panel can render each as a badge.
// kind: date | week | day | lunar | holiday | obs | today | future | past | arrow | span
function describeParts(k, todayKey) {
    var parts = [{ t: dateText(k), kind: "date" },
                 { t: "week " + isoWeek(k), kind: "week" },
                 { t: "day " + dayOfYear(k) + "/" + daysInYear(keyYear(k)), kind: "day" },
                 { t: lunarFull(k), kind: "lunar" }]
    var h = dayInfo(k).holiday
    if (h) parts.push({ t: h.name, kind: h.kind })
    var n = daysBetween(todayKey, k)
    parts.push({ t: relativeText(k, todayKey), kind: n === 0 ? "today" : n > 0 ? "future" : "past" })
    return parts
}

// Segments for an inclusive-start range a..b (a <= b).
function describeRangeParts(a, b) {
    var n = daysBetween(a, b)
    return [{ t: dateText(a, keyYear(a) !== keyYear(b)), kind: "date" },
            { t: "→", kind: "arrow" },
            { t: dateText(b), kind: "date" },
            { t: n + " day" + (n === 1 ? "" : "s") + " apart", kind: "span" },
            { t: (n + 1) + " inclusive", kind: "day" }]
}

function joinParts(parts) {
    var out = ""
    for (var i = 0; i < parts.length; i++) {
        var p = parts[i], prev = parts[i - 1]
        if (i === 0) out = p.t
        else if (p.kind === "arrow" || (prev && prev.kind === "arrow")) out += " " + p.t
        else out += " · " + p.t
    }
    return out
}

// One-line plain-text forms.
function describe(k, todayKey) { return joinParts(describeParts(k, todayKey)) }
function describeRange(a, b) { return joinParts(describeRangeParts(a, b)) }

// Multi-line tooltip for the bar clock.
function tooltipText(k) {
    var h = dayInfo(k).holiday
    return dateText(k) + "\nWeek " + isoWeek(k) + " · day " + dayOfYear(k) + "/" + daysInYear(keyYear(k))
        + "\n" + lunarFull(k) + (h ? "\n" + h.name : "")
}
