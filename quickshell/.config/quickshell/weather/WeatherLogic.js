.pragma library

// Unit conversion and labelling for the weather widget/panel. Colour helpers
// return Theme token names (e.g. "yellow"); callers look them up on the theme.

var WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

function temp(c, fahrenheit) {
    if (c === null || c === undefined) return "--"
    return String(Math.round(fahrenheit ? c * 9 / 5 + 32 : c))
}

function tempUnit(fahrenheit) { return fahrenheit ? "°F" : "°C" }

function wind(kmh, mph) {
    if (kmh === null || kmh === undefined) return "--"
    return mph ? Math.round(kmh * 0.621371) + " mph" : Math.round(kmh) + " km/h"
}

// US AQI bands.
function aqi(v) {
    if (v === null || v === undefined) return { label: "", key: "subtext0" }
    if (v <= 50)  return { label: "Good", key: "green" }
    if (v <= 100) return { label: "Moderate", key: "yellow" }
    if (v <= 150) return { label: "Unhealthy for sensitive groups", key: "peach" }
    if (v <= 200) return { label: "Unhealthy", key: "red" }
    if (v <= 300) return { label: "Very unhealthy", key: "mauve" }
    return { label: "Hazardous", key: "maroon" }
}

function uv(v) {
    if (v === null || v === undefined) return { label: "", key: "subtext0" }
    if (v < 3)  return { label: "Low", key: "green" }
    if (v < 6)  return { label: "Moderate", key: "yellow" }
    if (v < 8)  return { label: "High", key: "peach" }
    if (v < 11) return { label: "Very high", key: "red" }
    return { label: "Extreme", key: "mauve" }
}

// Icon colour by weather kind (see weather-detail.sh).
function kindKey(kind, isDay) {
    switch (kind) {
    case "clear":   return isDay ? "yellow" : "lavender"
    case "partly":  return isDay ? "peach" : "lavender"
    case "cloud":   return "subtext1"
    case "fog":     return "overlay2"
    case "drizzle": return "sapphire"
    case "rain":    return "blue"
    case "storm":   return "mauve"
    case "snow":    return "sky"
    default:        return "subtext0"
    }
}

function rainKey(p) { return p >= 60 ? "blue" : p >= 30 ? "sapphire" : "overlay0" }

// "YYYY-MM-DD" -> "Today" for the first row, else the weekday.
function dayName(dateStr, index) {
    if (index === 0) return "Today"
    var p = dateStr.split("-")
    return WEEKDAYS[new Date(+p[0], +p[1] - 1, +p[2]).getDay()]
}

function clock(epoch) {
    if (!epoch) return ""
    var d = new Date(epoch * 1000)
    var h = d.getHours(), m = d.getMinutes()
    return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
}
