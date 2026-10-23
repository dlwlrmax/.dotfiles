.pragma library

// Search matching + match highlighting for the notification panel.
// Matching is case- and diacritic-insensitive ("thuy anh" matches "Thùy Anh").

// Lowercase, strip diacritics (đ has no decomposition).
function fold(s) {
    return String(s || "").toLowerCase().normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "").replace(/đ/g, "d")
}

var _entities = { "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'" }

// Wrap every match of `needle` (already folded) in StyledText markup `styled`
// (output of Sanitize.formatBody or Sanitize.escapePlain) with a colored bold span. Tags
// are never split: a match crossing one is closed before it and reopened after.
function mark(styled, needle, color) {
    styled = String(styled || "")
    if (!needle) return styled

    // Units: one tag, one entity, or one character; folded text maps back to units.
    var units = [], hay = "", owner = []
    var re = /<[^>]*>|&[#a-zA-Z0-9]+;|[\s\S]/g, m
    while ((m = re.exec(styled)) !== null) {
        var raw = m[0], isTag = raw.charAt(0) === "<" && raw.length > 1
        units.push({ raw: raw, tag: isTag, hit: false })
        if (isTag) continue
        var f = fold(_entities[raw] || raw)
        for (var k = 0; k < f.length; k++) { hay += f.charAt(k); owner.push(units.length - 1) }
    }

    for (var at = hay.indexOf(needle); at >= 0; at = hay.indexOf(needle, at + needle.length))
        for (var j = owner[at]; j <= owner[at + needle.length - 1]; j++)
            if (!units[j].tag) units[j].hit = true

    var open = "<b><font color=\"" + color + "\">", close = "</font></b>"
    var out = "", inHit = false
    for (var i = 0; i < units.length; i++) {
        var u = units[i]
        if (u.hit !== inHit) { out += u.hit ? open : close; inHit = u.hit }
        out += u.raw
    }
    if (inHit) out += close
    return out
}
