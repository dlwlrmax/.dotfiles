.pragma library

// Shared notification grouping rules for the popup, the panel and the cards.

// KDE Connect relays phone notifications under one desktop entry.
function isKde(n) {
    if (!n) return false
    var app = (n.appName || "").trim().toLowerCase()
    var de = (n.desktopEntry || "").trim().toLowerCase()
    return app === "kde connect" || de.indexOf("kdeconnect") >= 0
}

// Notifications with the same key, adjacent in time, share one card. KDE
// Connect puts the phone app's name in the summary, so Zalo and Messenger
// count as different apps. desktopEntry is the stable id for everything
// else; bare appName varies in case/whitespace per sender.
function appKey(n) {
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
// them around after splitting. A single message is returned untouched.
function mergedView(messages) {
    var latest = messages[0]
    if (messages.length === 1) return latest
    var sameSummary = true
    for (var i = 1; i < messages.length; ++i)
        if ((messages[i].summary || "") !== (latest.summary || "")) sameSummary = false
    var kde = isKde(latest)
    var list = []
    var plain = []
    for (var j = 0; j < messages.length; ++j) {
        var m = messages[j]
        var text = m.body || ""
        var flip = kde
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
