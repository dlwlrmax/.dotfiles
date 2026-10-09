pragma Singleton
import QtQuick

// Shared HTML sanitizer for untrusted notification text (any local app via
// DBus, phone apps via KDE Connect relay). Display path only — never used
// for comparison or storage.
//
// Pipeline: decode entities → normalize breaks → escape EVERYTHING → reopen
// bare <b>/<i>/<u> only. Attributes can never survive: "<b onclick=..>"
// does not match the bare-tag pattern and stays literal. <img>/<a>/<script>
// and all other tags render as literal text. Pair with Text.StyledText
// (no image/link support) as defense in depth.
QtObject {
    function formatBody(s) {
        var t = String(s || "")
        if (!t) return ""
        // 1. decode entities, single pass, &amp; last (no double-decode:
        // "&amp;lt;" becomes "&lt;" and displays literally, never as a tag)
        t = t.replace(/&#x([0-9a-fA-F]+);/g, function(m, h) { return String.fromCharCode(parseInt(h, 16)) })
            .replace(/&#(\d+);/g, function(m, d) { return String.fromCharCode(parseInt(d, 10)) })
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"")
            .replace(/&#39;/g, "'").replace(/&apos;/g, "'")
            .replace(/&nbsp;/g, " ").replace(/&amp;/g, "&")
        // 2. block breaks to newline before escaping (so no <br> allowlist
        // is needed at all — StyledText renders \n as a break)
        t = t.replace(/<\s*\/?\s*(br|p)\s*\/?\s*>/gi, "\n")
        // 3. escape everything
        t = t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        // 4. reopen bare b/i/u tags only — anything with attributes,
        // whitespace, or different tag names stays escaped
        t = t.replace(/&lt;(\/?)(b|i|u)&gt;/gi, "<$1$2>")
        return t
    }
}
