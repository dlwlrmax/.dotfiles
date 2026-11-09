.pragma library

// Shared notification grouping rules for the popup, the panel and the cards.

// KDE Connect relays phone notifications under one desktop entry.
function isKde(n) {
    if (!n) return false
    var app = (n.appName || "").trim().toLowerCase()
    var de = (n.desktopEntry || "").trim().toLowerCase()
    return app === "kde connect" || de.indexOf("kdeconnect") >= 0
}

// Messaging apps: the only ones whose notifications merge into one card and
// whose cumulative bodies may list the newest message last. Mail, calendar and
// the like keep one card per notification and their text in order. KDE
// Connect names the phone app in the summary; native apps use their ids.
// Distinctive names match anywhere in the id; common words ("line", "signal")
// only against the summary (KDE Connect) or desktop entry, never the app name.
var _chatName = /(^|[^a-z])(zalo|messenger|telegram|whatsapp|viber|skype|discord|vesktop|slack|wechat|kakaotalk|sms|messages|instagram|facebook|google ?chat|hangouts|mattermost)([^a-z]|$)/
var _chatWord = /(^|[^a-z])(line|signal|teams|element)([^a-z]|$)/
function isChat(n) {
    if (!n) return false
    var strong, weak
    if (isKde(n)) {
        strong = weak = (n.summary || "")
    } else {
        weak = (n.desktopEntry || "")
        strong = weak + " " + (n.appName || "")
    }
    return _chatName.test(strong.toLowerCase()) || _chatWord.test(weak.toLowerCase())
}

// Body lines with tags stripped, blanks dropped.
function _lines(text) {
    return String(text || "").split(/\n|<br\s*\/?>/i)
        .map(function(l) { return l.replace(/<[^>]*>/g, "").trim() })
        .filter(function(l) { return l !== "" })
}

// "Name: text" — a sender (or conversation) name leading the line.
var _prefixed = /^([^<>:]{1,60}):\s*(\S.*)$/
// "<b>Sender</b>" alone on a line: group-chat relays (Messenger) head each
// run of one sender's messages with it.
var _senderLine = /^<b>[^<>]{1,80}<\/b>$/

// Every line of a multi-line body reads as its own "Name: text" message.
// Anything less clear (a wrapped paragraph, a mail body) is left alone.
function clearLines(text) {
    var lines = _lines(text)
    if (lines.length < 2) return false
    for (var i = 0; i < lines.length; ++i)
        if (!_prefixed.test(lines[i])) return false
    return true
}

// This notification's own body lists its messages oldest-first, one per
// line, so it should be read bottom-up (see newestFirst). That is a KDE
// Connect chat whose first line names the sender or conversation:
//   "A: hi" / "B: yo"                      every line prefixed
//   "Giang: hi" / "there"                  1:1, the name on the first only
//   "Group: <b>A</b>" / "hi" / "<b>B</b>" / "yo"   group, sender blocks
// Anything else keeps the order it was sent in.
function flips(n) {
    if (!isKde(n) || !isChat(n)) return false
    var lines = _lines(n.body)
    return lines.length >= 2 && _prefixed.test(lines[0])
}

// Formatted body lines (oldest first, as flips accepts them) -> newest first.
// The leading "Name: " stays on the top line, and in a group body each
// "<b>Sender</b>" header stays above its own messages.
function newestFirst(lines) {
    if (lines.length < 2) return lines.slice()
    var plain = function(l) { return l.replace(/<[^>]*>/g, "").trim() }
    var m = _prefixed.exec(lines[0])
    if (!m || lines.every(function(l) { return _prefixed.test(plain(l)) }))
        return lines.slice().reverse()
    var rest = [m[2]].concat(lines.slice(1))
    var out = []
    if (_senderLine.test(rest[0])) {
        var blocks = []
        for (var i = 0; i < rest.length; ++i) {
            if (_senderLine.test(rest[i])) blocks.push([rest[i]])
            else blocks[blocks.length - 1].push(rest[i])
        }
        for (var b = blocks.length - 1; b >= 0; --b)
            out = out.concat([blocks[b][0]], blocks[b].slice(1).reverse())
    } else {
        out = rest.reverse()
    }
    out[0] = m[1] + ": " + out[0]
    return out
}

// Notifications with the same key, adjacent in time, share one card. KDE
// Connect puts the phone app's name in the summary, so Zalo and Messenger
// count as different apps. desktopEntry is the stable id for everything
// else; bare appName varies in case/whitespace per sender. Non-chat apps get
// a key of their own, so they never merge. The panel mixes live and history
// rows whose ids can match; popup snapshots never carry `dismiss` and so are
// always "h", consistently.
function appKey(n) {
    if (!isChat(n)) return "solo|" + (n.dismiss ? "l" : "h") + n.id
    if (isKde(n)) return "kdeconnect|" + (n.summary || "").trim().toLowerCase()
    var de = (n.desktopEntry || "").trim().toLowerCase()
    if (de) return de
    var app = (n.appName || "").trim().toLowerCase()
    if (app) return app
    return n.appIcon || "unknown"
}

// messages newest first -> one notification-shaped object for the whole run.
// bodyList holds one entry per message, newest first; flip marks bodies that
// list their own lines oldest-first (KDE Connect chats) so NotifBody turns
// them around after splitting (see flips). A single message is returned as is.
function mergedView(messages) {
    var latest = messages[0]
    if (messages.length === 1) return latest
    var sameSummary = true
    for (var i = 1; i < messages.length; ++i)
        if ((messages[i].summary || "") !== (latest.summary || "")) sameSummary = false
    var list = []
    var plain = []
    for (var j = 0; j < messages.length; ++j) {
        var m = messages[j]
        var text = m.body || ""
        var flip = flips(m)
        if (!sameSummary && m.summary) {
            text = m.summary + (text ? ": " + text : "")
            flip = false
        } else if (!text) {
            text = m.summary || ""
            flip = false
        }
        list.push({ text: text, flip: flip })
        plain.push(text)
    }
    return {
        id: latest.id,
        merged: true,
        appName: latest.appName,
        summary: sameSummary ? (latest.summary || "") : "",
        body: plain.join("\n"),
        bodyList: list,
        urgency: latest.urgency,
        timestamp: latest.timestamp,
        appIcon: latest.appIcon,
        desktopEntry: latest.desktopEntry,
        actions: latest.actions
    }
}
