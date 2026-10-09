pragma Singleton
import QtQuick

// Shared HTML sanitizer for untrusted notification text (any local app via
// DBus, phone apps via KDE Connect relay). Display path only — never used
// for comparison or storage.
//
// Pipeline: decode entities → breaks to <br> → escape EVERYTHING → reopen
// bare <b>/<i>/<u>/<br> only. Attributes can never survive: "<b onclick=..>"
// does not match the bare-tag pattern and stays literal. <img>/<a>/<script>
// and all other tags render as literal text. Pair with Text.StyledText
// (no image/link support) as defense in depth.
// NOTE: StyledText follows HTML whitespace rules, so a literal \n collapses
// to a space — line breaks must be real <br> tags, never \n.
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
        // 2. breaks to <br>: <br>/<p> in any case/slash form (attrs on
        // these two are dropped, not kept) plus native newlines — multiline
        // bodies must keep their breaks too
        t = t.replace(/<\s*\/?\s*(br|p)(\s[^<>]*)?\s*\/?\s*>/gi, "<br>")
        // 3. escape everything
        t = t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        // 4. native newlines to <br> (plain \n collapses under StyledText)
        t = t.replace(/\n/g, "<br>")
        // 5. reopen bare b/i/u/br tags only — anything with attributes,
        // whitespace, or different tag names stays escaped
        t = t.replace(/&lt;(\/?)(b|i|u|br)&gt;/gi, "<$1$2>")
            .replace(/&lt;br\s*\/&gt;/gi, "<br>")
        return t
    }
}
