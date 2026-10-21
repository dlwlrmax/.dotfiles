import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common
import "LauncherLogic.js" as L

// App launcher on top of PickerPanel. Search apps (accent-insensitive, recency +
// frequency ranked), open an app's desktop actions with → / Tab, and use the
// quick prefixes:  =  calculator   >  run a command   ?  web search   @  windows.
Item {
    id: root
    property Theme theme: ThemeStore
    property bool active: false
    signal close()
    signal appLaunched()

    implicitWidth: picker.implicitWidth
    implicitHeight: picker.implicitHeight

    property var allEntries: []
    property var recentApps: []
    property var _recentMap: ({})          // id -> last launch (epoch s)
    property var _counts: ({})             // id -> launch count
    property var _windows: []              // hyprctl clients, for the @ mode
    property var actionsFor: null
    property string terminal: ""
    property string _pendingFingerprint: ""
    property int loadTries: 0
    readonly property int maxResults: 120

    // ── text folding: lower-case, accents stripped, length preserved so match
    // positions map straight back onto the original string ──

    function fold(s) { return L.fold(s) }

    function escapeHtml(str) {
        return String(str).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    // Name with the matched part highlighted: the contiguous substring when there
    // is one, otherwise the fuzzy letters.
    function highlightHtml(name, fq) {
        if (!fq) return escapeHtml(name)
        var fname = fold(name), marks = {}
        var at = fname.indexOf(fq)
        if (at >= 0) {
            for (var k = 0; k < fq.length; k++) marks[at + k] = true
        } else {
            var ni = 0
            for (var i = 0; i < fq.length; i++) {
                var idx = fname.indexOf(fq.charAt(i), ni)
                if (idx < 0) return escapeHtml(name)
                marks[idx] = true
                ni = idx + 1
            }
        }
        var out = "", open = false
        for (var p = 0; p < name.length; p++) {
            var on = !!marks[p]
            if (on && !open) { out += "<span style='color:" + theme.peach + ";font-weight:bold'>"; open = true }
            if (!on && open) { out += "</span>"; open = false }
            out += escapeHtml(name.charAt(p))
        }
        return out + (open ? "</span>" : "")
    }

    // ── entries (SQLite snapshot first, then a cheap fingerprint check) ──

    function _applyEntries(list) {
        var next = []
        for (var i = 0; i < list.length; i++) {
            var e = list[i]
            if (e.noDisplay) continue
            var entry = {
                id: e.id,
                name: e.name || e.id,
                genericName: e.genericName || "",
                icon: e.icon || "",
                exec: e.exec || "",
                categories: e.categories || "",
                keywords: e.keywords || "",
                comment: e.comment || "",
                terminal: e.terminal,
                actions: e.actions || []
            }
            entry.fname = fold(entry.name)
            entry.fgeneric = fold(entry.genericName)
            entry.fkeywords = fold(entry.keywords)
            entry.fcomment = fold(entry.comment)
            entry.fcategories = fold(entry.categories)
            next.push(entry)
        }
        root.allEntries = next
        root.rebuild()
    }

    function loadEntries() {
        var cached = Db.loadApps()
        if (cached.length > 0) root._applyEntries(cached)
        if (!fpProc.running) fpProc.running = true
    }

    Process {
        id: fpProc
        command: ["bash", theme.scriptDir + "/desktop-entries.sh", "--fingerprint"]

        stdout: StdioCollector {
            onStreamFinished: {
                var fp = this.text.trim()
                if (root.allEntries.length === 0 || fp !== Db.getAppsFingerprint()) {
                    root._pendingFingerprint = fp
                    if (!fullProc.running) fullProc.running = true
                }
            }
        }
    }

    Process {
        id: fullProc
        command: ["bash", theme.scriptDir + "/desktop-entries.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim())
                    if (!Array.isArray(data)) return
                    Db.replaceApps(data)
                    if (root._pendingFingerprint.length > 0)
                        Db.setAppsFingerprint(root._pendingFingerprint)
                    root._applyEntries(Db.loadApps())
                } catch (ex) {
                    console.log("Launcher: parse error", ex.message)
                }
            }
        }
    }

    // Retry (bounded) while the app list is still empty; refresh while open.
    Timer {
        interval: 2000
        repeat: true
        running: root.active && root.allEntries.length === 0 && root.loadTries < 30
        onTriggered: { root.loadTries++; root.loadEntries() }
    }

    Timer {
        interval: 300000
        repeat: true
        running: root.active
        onTriggered: root.loadEntries()
    }

    // ── terminal for Terminal=true apps and `>` runs ──

    Process {
        id: termProc
        command: ["bash", "-c", 'for t in "$TERMINAL" ghostty kitty alacritty foot xterm; do [ -n "$t" ] && command -v "$t" >/dev/null 2>&1 && { echo "$t"; exit 0; }; done']
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.terminal = this.text.trim()
        }
    }

    // argv wrapped so `argv` runs inside a terminal window (kitty takes the command bare).
    function inTerminal(argv) {
        var t = root.terminal
        if (!t) return argv
        var base = t.split("/").pop()
        return base === "kitty" ? [t].concat(argv) : [t, "-e"].concat(argv)
    }

    // ── recents + frequency ──

    function loadRecent() {
        root.recentApps = Db.loadRecents()
        root._buildRecentMap()
        var row = Db.cacheGet("launchcounts")
        if (row) { try { root._counts = JSON.parse(row.json) } catch (e) {} }
    }

    function _buildRecentMap() {
        var m = ({})
        for (var i = 0; i < root.recentApps.length; i++) m[root.recentApps[i].id] = root.recentApps[i].time
        root._recentMap = m
    }

    function _recencyBoost(id) {
        var t = root._recentMap[id]
        if (t === undefined) return 0
        var diff = Math.floor(Date.now() / 1000) - t
        if (diff < 3600) return 400
        if (diff < 14400) return 250
        if (diff < 86400) return 150
        if (diff < 604800) return 60
        return 10
    }

    // Launch count, log-scaled so a favourite doesn't bury an exact match.
    function _frequencyBoost(id) {
        var c = root._counts[id] || 0
        return Math.min(240, Math.round(Math.log(c + 1) / Math.LN2 * 45))
    }

    function markRecent(entryId) {
        var now = Math.floor(Date.now() / 1000)
        for (var i = 0; i < root.recentApps.length; i++) {
            if (root.recentApps[i].id === entryId) { root.recentApps.splice(i, 1); break }
        }
        root.recentApps.unshift({ id: entryId, time: now })
        while (root.recentApps.length > 30) root.recentApps.pop()
        root._buildRecentMap()
        Db.markRecent(entryId, now)
        var c = Object.assign({}, root._counts)
        c[entryId] = (c[entryId] || 0) + 1
        root._counts = c
        Db.cachePut("launchcounts", JSON.stringify(c))
    }

    // ── matching ──

    function _fuzzyPos(text, q) {
        var ni = 0
        for (var i = 0; i < q.length; i++) {
            var idx = text.indexOf(q.charAt(i), ni)
            if (idx === -1) return -1
            ni = idx + 1
        }
        return ni - q.length
    }

    function _wordPrefix(text, q) {
        return text.indexOf(" " + q) !== -1 || text.indexOf("-" + q) !== -1
    }

    // {score, reason}: reason is "" for name matches, else what matched.
    function scoreEntry(e, fq) {
        var name = e.fname, s = 0, reason = ""
        if (name === fq) s = 1000
        else if (name.indexOf(fq) === 0) s = 500
        else if (_wordPrefix(name, fq)) s = 300
        else if (name.indexOf(fq) !== -1) s = 100
        else if (fq.length >= 2 && _fuzzyPos(name, fq) !== -1) s = 30 + Math.max(0, 10 - _fuzzyPos(name, fq))
        else if (e.fkeywords.indexOf(fq) !== -1) { s = 60; reason = "keyword" }
        else if (e.fgeneric.indexOf(fq) !== -1) { s = 50; reason = "generic" }
        else if (e.fcomment.indexOf(fq) !== -1) { s = 20; reason = "comment" }
        else if (e.fcategories.indexOf(fq) !== -1) { s = 10; reason = "category" }
        if (s === 0) return { score: 0, reason: "" }
        return { score: s + root._recencyBoost(e.id) + root._frequencyBoost(e.id), reason: reason }
    }

    function appRow(e, fq, reason) {
        var sub = e.genericName || e.comment
        if (reason === "keyword") sub = "keyword · " + (e.keywords.split(";")[0] || "") + (sub ? " · " + sub : "")
        else if (reason === "category") sub = e.categories.split(";")[0] + (sub ? " · " + sub : "")
        return {
            kind: "app", entry: e,
            title: e.name,
            titleHtml: fq ? highlightHtml(e.name, fq) : "",
            subtitle: sub,
            icon: { appId: e.id, name: e.icon, fallbackGlyph: "\udb81\udd6c" },
            tag: e.actions.length > 0 ? "\u203a" : (e.terminal ? "term" : "")
        }
    }

    // ── calculator ──

    function calc(src) { return L.calc(src) }

    function formatNumber(n) { return L.formatNumber(n) }

    function calcRow(expr) {
        var r = calc(expr)
        if (r === null) return null
        var txt = formatNumber(r)
        return { kind: "calc", value: txt, title: "= " + txt, subtitle: expr.trim() + "  ·  ↵ copy result",
                 glyph: "\uf1ec", glyphClr: theme.green }
    }

    // ── windows (@) ──

    function loadWindows() {
        if (!winProc.running) winProc.running = true
    }

    Process {
        id: winProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root._windows = JSON.parse(this.text).filter(function (c) { return c.mapped && c.title !== "" })
                } catch (e) { root._windows = [] }
                root.rebuild()
            }
        }
    }

    // ── rows ──

    function isUrl(q) { return L.isUrl(q) }

    function webRows(q) {
        var rows = []
        if (isUrl(q)) {
            var url = /^https?:\/\//i.test(q) ? q : "https://" + q
            rows.push({ kind: "url", url: url, title: "Open " + url, subtitle: "in the default browser",
                        glyph: "\uf0ac", glyphClr: theme.blue })
        }
        rows.push({ kind: "web", url: "https://duckduckgo.com/?q=" + encodeURIComponent(q),
                    title: "Search the web for \u201c" + q + "\u201d", subtitle: "DuckDuckGo",
                    glyph: "\uf002", glyphClr: theme.blue })
        return rows
    }

    function actionRows() {
        var e = root.actionsFor
        var rows = [{ kind: "app", entry: e, title: "Launch " + e.name,
                      icon: { appId: e.id, name: e.icon, fallbackGlyph: "\udb81\udd6c" }, subtitle: "default" }]
        for (var i = 0; i < e.actions.length; i++) {
            var a = e.actions[i]
            rows.push({ kind: "action", entry: e, action: a, title: a.name, subtitle: e.name,
                        glyph: "\uf054", glyphClr: theme.subtext0 })
        }
        return rows
    }

    function rebuild() {
        if (root.actionsFor) { picker.rows = actionRows(); return }
        var q = picker.query
        var trimmed = q.trim()

        if (trimmed.charAt(0) === "=") {
            var cr = calcRow(trimmed.slice(1))
            picker.rows = cr ? [cr] : []
            picker.emptyText = trimmed.length > 1 ? "can't calculate that" : "type an expression, e.g. =(12+8)*3"
            return
        }
        if (trimmed.charAt(0) === ">") {
            var cmd = trimmed.slice(1).trim()
            picker.rows = cmd ? [{ kind: "cmd", cmd: cmd, title: "Run  " + cmd, subtitle: "↵ run · ⇧↵ run in a terminal",
                                   glyph: "\uf120", glyphClr: theme.peach }] : []
            picker.emptyText = "type a command to run"
            return
        }
        if (trimmed.charAt(0) === "?") {
            var wq = trimmed.slice(1).trim()
            picker.rows = wq ? webRows(wq) : []
            picker.emptyText = "type what to search for"
            return
        }
        if (trimmed.charAt(0) === "@") {
            var wf = fold(trimmed.slice(1).trim())
            var wrows = []
            for (var w = 0; w < root._windows.length; w++) {
                var c = root._windows[w]
                var hay = fold(c.title + " " + c["class"])
                if (wf && hay.indexOf(wf) === -1) continue
                wrows.push({ kind: "window", address: c.address, title: c.title,
                             subtitle: c["class"] + " · workspace " + (c.workspace ? c.workspace.name : "?"),
                             icon: { appId: c["class"], name: c["class"], fallbackGlyph: "\uf2d0" } })
            }
            picker.rows = wrows
            picker.emptyText = root._windows.length === 0 ? "loading windows…" : "no matching windows"
            return
        }

        picker.emptyText = root.allEntries.length === 0 ? "loading apps…" : "no matches"
        var rows = []
        if (!trimmed) {
            var recent = [], rest = []
            for (var i = 0; i < root.allEntries.length; i++) {
                var e = root.allEntries[i]
                if (root._recentMap[e.id] !== undefined) recent.push(e); else rest.push(e)
            }
            recent.sort(function (a, b) { return root._recentMap[b.id] - root._recentMap[a.id] })
            rest.sort(function (a, b) { return a.name.localeCompare(b.name) })
            if (recent.length > 0) {
                rows.push({ isHeader: true, label: "Recent" })
                recent.slice(0, 8).forEach(function (e2) { rows.push(appRow(e2, "", "")) })
                rest = rest.concat(recent.slice(8))
            }
            rows.push({ isHeader: true, label: "Apps" })
            rest.slice(0, root.maxResults).forEach(function (e3) { rows.push(appRow(e3, "", "")) })
            picker.rows = rows
            picker.status = root.allEntries.length + " apps"
            return
        }

        var fq = fold(trimmed)
        var scored = []
        for (var j = 0; j < root.allEntries.length; j++) {
            var r = scoreEntry(root.allEntries[j], fq)
            if (r.score > 0) scored.push({ entry: root.allEntries[j], score: r.score, reason: r.reason })
        }
        scored.sort(function (a, b) { return b.score - a.score })
        var total = scored.length
        scored.slice(0, root.maxResults).forEach(function (x) { rows.push(appRow(x.entry, fq, x.reason)) })

        // Arithmetic typed without "=": offer the result first.
        if (/^[\d\s().,+\-*\/%^]+$/.test(trimmed) && /\d\s*[+\-*\/%^]\s*[\d(]/.test(trimmed)) {
            var auto = calcRow(trimmed)
            if (auto) rows.unshift(auto)
        }
        // Nothing found (or it looks like a URL): fall back to the web.
        if (rows.length === 0 || isUrl(trimmed)) rows = rows.concat(webRows(trimmed))

        picker.rows = rows
        picker.status = total > root.maxResults ? root.maxResults + " of " + total : (total > 0 ? total + "" : "")
    }

    // ── launching ──

        // Parse a freedesktop.org Exec= string into an argv array without invoking
    function parseXdgExec(exec, entry) { return L.parseXdgExec(exec, entry) }


    function _exec(argv) {
        if (argv.length === 0) return
        Quickshell.execDetached({ command: argv, workingDirectory: Quickshell.env("HOME") })
    }

    function launch(entry) {
        if (!entry) return
        var argv = parseXdgExec(entry.exec || "", entry)
        if (argv.length === 0) return
        if (entry.terminal) argv = inTerminal(argv)
        root.markRecent(entry.id)
        _exec(argv)
        appLaunched()
        close()
    }

    function launchAction(entry, action) {
        var argv = parseXdgExec(action.exec || "", entry)
        if (argv.length === 0) return
        if (entry.terminal) argv = inTerminal(argv)
        root.markRecent(entry.id)
        _exec(argv)
        appLaunched()
        close()
    }

    function activate(row, alt) {
        switch (row.kind) {
        case "app":    launch(row.entry); break
        case "action": launchAction(row.entry, row.action); break
        case "calc":
            _exec(["wl-copy", row.value]); close(); break
        case "cmd":
            _exec(alt ? inTerminal(["bash", "-c", row.cmd + "; echo; read -rp 'Press Enter to close… '"])
                      : ["bash", "-c", row.cmd])
            close(); break
        case "web":
        case "url":
            _exec(["xdg-open", row.url]); close(); break
        case "window":
            _exec(["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:" + row.address + "\" })"])
            close(); break
        }
    }

    function openActions(row) {
        if (row.kind !== "app" || !row.entry || row.entry.actions.length === 0) return
        root.actionsFor = row.entry
        picker.canGoBack = true
        picker.reset()
        picker.query = ""
        rebuild()
    }

    function back() {
        root.actionsFor = null
        picker.canGoBack = false
        picker.reset()
        picker.query = ""
        rebuild()
    }

    onActiveChanged: {
        if (!active) return
        actionsFor = null
        picker.canGoBack = false
        picker.reset()
        picker.query = ""
        picker.searchMode = true
        loadTries = 0
        loadRecent()
        loadEntries()
        rebuild()
        Qt.callLater(function () { picker.focusSearch() })
    }

    Component.onCompleted: loadRecent()

    PickerPanel {
        id: picker
        anchors.fill: parent
        theme: root.theme
        active: root.active
        modal: true
        placeholder: "Search apps…   (= calc · > run · ? web · @ windows)"
        iconSize: 28
        rowHeight: 48
        hints: root.actionsFor ? "↵ run · ← back · esc back"
             : searchMode ? "↑↓ move · ↵ launch · → actions · = > ? @ modes · esc close"
                          : "j/k move · / search · ↵ launch · esc close"

        onQueryChanged: {
            if (!root.actionsFor && picker.query.trim().charAt(0) === "@") root.loadWindows()
            root.rebuild()
        }
        onActivated: (row, alt) => root.activate(row, alt)
        onSecondary: row => root.openActions(row)
        onBackRequested: root.back()
        onCloseRequested: root.close()
    }
}
