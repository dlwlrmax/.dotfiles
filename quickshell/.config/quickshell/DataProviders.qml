// DataProviders — shared data models, notification server, and polling processes.
// Extracted from shell.qml. Property aliases let the outer scope bind to each source.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property alias kdeData: kdeData
    property alias notifServer: notifServer
    property alias notifData: notifData
    property alias cpuData: cpuData
    property alias netData: netData
    property alias weatherData: weatherData
    property alias volumeData: volumeData
    property alias batteryData: batteryData

    function cycleAudio() { volumeData.cycleSink() }

    // ── KDE Connect ─────────────────────────────────────────

    Item {
        id: kdeData
        property var devices: []
        property var device: devices.length > 0 ? devices[0] : null
        property bool anyConnected: false
        // Recently-dismissed nids (nid -> epoch ms). Stale polls landing
        // inside the window get filtered so cleared items stay cleared.
        property var suppressed: ({})
        property bool refreshPending: false

        function pruneSuppressed(now) {
            var out = {}
            for (var k in suppressed) {
                if (now - suppressed[k] < 60000) out[k] = suppressed[k]
            }
            suppressed = out
        }

        function applyDevices(devs) {
            var now = Date.now()
            pruneSuppressed(now)
            var filtered = []
            for (var d = 0; d < devs.length; d++) {
                var dev = devs[d]
                var notifs = dev.notifications || []
                var kept = []
                for (var i = 0; i < notifs.length; i++) {
                    var nid = notifs[i].id
                    if (suppressed[nid] !== undefined && now - suppressed[nid] < 60000) continue
                    kept.push(notifs[i])
                }
                if (kept.length !== notifs.length) {
                    var copy = {}
                    for (var k in dev) copy[k] = dev[k]
                    copy.notifications = kept
                    copy.notifCount = kept.length
                    filtered.push(copy)
                } else {
                    filtered.push(dev)
                }
            }
            kdeData.devices = filtered
        }

        function applyJson(text) {
            try {
                var data = JSON.parse(text.trim())
                applyDevices(data.devices || [])
                anyConnected = data.anyConnected || false
                return true
            } catch (e) {
                console.log("KDEConnectData parse error:", e)
                return false
            }
        }

        // Cache-first poll: reuse the SQLite snapshot while fresh (8s),
        // otherwise hit the fetcher script.
        function poll() {
            var row = Db.cacheGet("kde")
            if (Db.cacheFresh(row)) {
                applyJson(row.json)
                return
            }
            if (!fetchProc.running) fetchProc.running = true
        }

        Process {
            id: fetchProc
            command: [theme.scriptDir + "/kdeconnect.sh"]

            stdout: StdioCollector {
                onStreamFinished: {
                    if (kdeData.applyJson(this.text)) Db.cachePut("kde", this.text)
                    if (kdeData.refreshPending) {
                        kdeData.refreshPending = false
                        if (!fetchProc.running) fetchProc.running = true
                    }
                }
            }
        }

        Timer {
            id: kdePollTimer
            interval: 10000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: kdeData.poll()
        }

        function refresh() {
            if (!fetchProc.running) fetchProc.running = true
            else refreshPending = true
        }

        function stampSuppressed(nid) {
            var m = {}
            for (var k in suppressed) m[k] = suppressed[k]
            m[nid] = Date.now()
            suppressed = m
        }

        // Remove one notification locally so dismiss feels instant.
        // Authoritative state arrives on next poll.
        function dismissOptimistic(devId, nid) {
            var devs = kdeData.devices
            var changed = false
            for (var d = 0; d < devs.length; d++) {
                var dev = devs[d]
                if (devId && dev.id !== devId) continue
                var notifs = dev.notifications || []
                var kept = []
                var devChanged = false
                for (var i = 0; i < notifs.length; i++) {
                    if (notifs[i].id !== nid) kept.push(notifs[i])
                    else { devChanged = true; stampSuppressed(nid) }
                }
                if (devChanged) {
                    var copy = {}
                    for (var k in dev) copy[k] = dev[k]
                    copy.notifications = kept
                    copy.notifCount = kept.length
                    devs = devs.slice(0, d).concat([copy]).concat(devs.slice(d + 1))
                    changed = true
                }
            }
            if (changed) {
                kdeData.devices = devs
                Db.cacheInvalidate("kde")
                kdeData.refresh()
            }
        }

        // Remove all dismissable locally so Clear feels instant + persists
        // across the 10s poll gap. Ongoing (dismissable=false) stays.
        function clearOptimistic(devId) {
            var devs = kdeData.devices
            var changed = false
            for (var d = 0; d < devs.length; d++) {
                var dev = devs[d]
                if (devId && dev.id !== devId) continue
                var notifs = dev.notifications || []
                var kept = []
                var devChanged = false
                for (var i = 0; i < notifs.length; i++) {
                    if (!notifs[i].dismissable) kept.push(notifs[i])
                    else { devChanged = true; stampSuppressed(notifs[i].id) }
                }
                if (devChanged) {
                    var copy = {}
                    for (var k in dev) copy[k] = dev[k]
                    copy.notifications = kept
                    copy.notifCount = kept.length
                    devs = devs.slice(0, d).concat([copy]).concat(devs.slice(d + 1))
                    changed = true
                }
            }
            if (changed) {
                kdeData.devices = devs
                Db.cacheInvalidate("kde")
                kdeData.refresh()
            }
        }

        Component.onCompleted: {
            poll()
        }
    }

    // ── Notification Server (DBus daemon, replaces mako) ────

    NotificationServer {
        id: notifServer
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: function(notif) {
            notifData.handleNotification(notif)
        }
    }

    // ── Notification Data Adapter ───────────────────────────

    Item {
        id: notifData
        property int count: 0
        property bool dnd: false
        property var activeNotifs: []
        property var notifTimes: ({})
        property var timesByKey: ({})
        // Mirror-window for cross-app duplicates of the same message
        // (e.g. Ferdium + KDE Connect WhatsApp relay): same sender + same
        // message core arriving via two apps within mirrorWindowSec
        // collapses to the first arrival. Sender linkage is required so
        // unrelated identical texts never match.
        // Null-prototype map: keys are message text, so a "__proto__" body
        // must not touch the prototype.
        property var mirrorTimes: Object.create(null)
        property int mirrorWindowSec: 30
        property var history: []
        // Total unread = live (active) notifications + unread history rows that
        // are not already represented by a live entry. This is the bar badge's
        // source of truth: it must stay > 0 while any unread notification exists,
        // even when nothing is actively popping. Mirrors the panel's totalCount.
        // Defined here (not just on the panel) so the bar icon can see it; the
        // binding re-evaluates whenever activeNotifs or history is reassigned.
        property int unreadCount: (function() {
            var live = activeNotifs ? activeNotifs.length : 0
            var ids = {}
            for (var i = 0; i < live; i++) {
                var d = activeNotifs[i]
                if (d && d._dbId !== undefined && d._dbId !== null) ids[d._dbId] = true
            }
            var rows = history ? history : []
            var unreadHist = 0
            for (var j = 0; j < rows.length; j++) {
                var r = rows[j]
                if (r.read === 1) continue
                if (r.id !== undefined && ids[r.id]) continue
                unreadHist++
            }
            return live + unreadHist
        })()
        property bool timesLoaded: false
        property var pendingNotifs: []
        property int lastSoundTime: 0
        property int startupTime: Date.now()
        signal newNotification(var notif)
        signal dismissPopup(var notifId)

        Component.onCompleted: loadSaved()

        // Notifications arriving before the saved-timestamp file loads are queued,
        // then dispatched once timesLoaded flips true so boot-time notifs are not lost.
        onTimesLoadedChanged: if (timesLoaded) flushPending()

        // Ask the server to close the live notification so activeNotifs
        // actually shrinks for apps that never emit CloseNotification on their
        // own. dismiss() is idempotent, so it is safe when the server already
        // auto-expired the entry. DB state (read/history) is untouched here.
        function requestDismissPopup(notifId) {
            var arr = activeNotifs
            for (var i = 0; i < arr.length; i++) {
                if (arr[i] && arr[i].id === notifId) {
                    arr[i].dismiss()
                    break
                }
            }
            dismissPopup(notifId)
        }

        // Dedup key: the full (appName, summary, body) tuple. The previous
        // 32-bit hash collided across distinct notifications and silently
        // dropped real ones inside the 5s startup window.
        function notifKey(notif) {
            return (notif.appName || "") + "|" + (notif.summary || "") + "|" + (notif.body || "")
        }

        // Some clients emit contentless Notify calls (no app name, summary,
        // body, icon, image or actions). They would render as blank "Unknown"
        // cards and pollute persistence, so they are dropped on ingest and load.
        function isContentless(n) {
            return !n.appName && !n.summary && !n.body && !n.appIcon
                && !n.desktopEntry && !n.image
                && (!n.actions || n.actions.length === 0)
        }

        // Bound the time maps: entries older than the startup dedup window are useless.
        function pruneTimes(cutoffSec) {
            var t = notifTimes
            for (var k in t) if (t[k] < cutoffSec) delete t[k]
            var m = timesByKey
            for (var k in m) if (m[k] < cutoffSec) delete m[k]
        }

        // Entities are decoded for comparison only (display stays PlainText
        // raw). Otherwise KDE's "&lt;br/&gt;" never equals Ferdium's "<br/>".
        // Numeric/hex refs + &apos;/&nbsp; covered: relays emit those while
        // desktop clients send the literal chars.
        function mirrorDecodeEntities(s) {
            return s.replace(/&#x([0-9a-fA-F]+);/g, function(m, h) { return String.fromCharCode(parseInt(h, 16)) })
                .replace(/&#(\d+);/g, function(m, d) { return String.fromCharCode(parseInt(d, 10)) })
                .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#39;/g, "'").replace(/&apos;/g, "'").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&")
        }

        // Strip leading media markers the phone relay prepends after the
        // sender prefix (photo/video/file thumbnails Ferdium does not add).
        // /u so astral pictographs match as code points; \uFE0F so
        // VS16-terminated markers (🖼️) strip fully instead of leaving FE0F.
        function mirrorStripMedia(s) {
            return s.replace(/^[📷🔗🎥🎙📄📹🖼🎞🎧📸\uFE0F]+\s*/u, "")
        }

        function mirrorSenderKey(s) {
            return (s || "").toLowerCase()
        }

        // Normalized identity of a notification for mirror matching: the
        // sender plus every plausible message core (full body, plus body
        // minus a leading "sender: " prefix). Ferdium carries body=message
        // while KDE carries body="sender: [emoji]message", so comparing
        // both forms is what lets the pair meet.
        function mirrorParts(notif) {
            var sender = ((notif.summary || "").replace(/\s+/g, " ")).trim()
            var body = mirrorDecodeEntities((notif.body || "").replace(/\s+/g, " ").trim())
            // Null-prototype: keys are message text, and "__proto__" as a
            // body would otherwise set the prototype instead of an entry.
            var cores = Object.create(null)
            var full = mirrorStripMedia(body)
            if (full) cores[full] = true
            var senderPart = ""
            // 64 chars + \s*: long names and "Alice:hi" (no space) relays.
            // False splits are harmless — sender linkage must still match.
            var m = body.match(/^([^:]{1,64}):\s*([\s\S]+)$/)
            if (m) {
                senderPart = m[1].trim()
                var rest = mirrorStripMedia(m[2].trim())
                if (rest) cores[rest] = true
            }
            return { sender: sender, senderPart: senderPart, cores: cores }
        }

        function isMirror(notif) {
            var p = mirrorParts(notif)
            var now = Date.now() / 1000
            var ps = mirrorSenderKey(p.sender)
            var psp = mirrorSenderKey(p.senderPart)
            for (var key in p.cores) {
                // Per-core entry LIST: same text from different senders
                // ("ok" from Alice, then "ok" from Bob) must not clobber.
                var list = mirrorTimes[key]
                if (!list) continue
                for (var i = 0; i < list.length; i++) {
                    var e = list[i]
                    if (!e || now - e.t > mirrorWindowSec) continue
                    if ((e.app || "") === (notif.appName || "")) continue
                    // Case-folded: "Alice" (Ferdium) meets "alice" (relay).
                    if ((e.senderL && (e.senderL === ps || (psp && e.senderL === psp)))
                        || (ps && e.senderPartL && ps === e.senderPartL)) return true
                }
            }
            return false
        }

        function rememberMirror(notif) {
            var p = mirrorParts(notif)
            // Senderless entries can never link — don't spend cap on them.
            if (!p.sender && !p.senderPart) return
            var t = Date.now() / 1000
            var entry = { t: t, app: notif.appName || "", senderL: mirrorSenderKey(p.sender), senderPartL: mirrorSenderKey(p.senderPart) }
            for (var key in p.cores) {
                var list = mirrorTimes[key]
                if (!list) { list = []; mirrorTimes[key] = list }
                list.push(entry)
            }
            pruneMirror(t)
        }

        function pruneMirror(now) {
            var keys = Object.keys(mirrorTimes)
            var total = 0
            var i, j, l
            for (i = 0; i < keys.length; i++) {
                l = mirrorTimes[keys[i]]
                for (j = l.length - 1; j >= 0; j--) if (now - l[j].t > mirrorWindowSec) l.splice(j, 1)
                if (!l.length) delete mirrorTimes[keys[i]]
                else total += l.length
            }
            // Expiry alone can't bound a fresh-message flood: drop oldest
            // first past the cap instead of growing without bound.
            if (total > 300) {
                var all = []
                keys = Object.keys(mirrorTimes)
                for (i = 0; i < keys.length; i++) {
                    l = mirrorTimes[keys[i]]
                    for (j = 0; j < l.length; j++) all.push({ k: keys[i], e: l[j] })
                }
                all.sort(function(a, b) { return a.e.t - b.e.t })
                for (i = 0; i < all.length - 250; i++) {
                    l = mirrorTimes[all[i].k]
                    if (!l) continue
                    var idx = l.indexOf(all[i].e)
                    if (idx >= 0) l.splice(idx, 1)
                    if (!l.length) delete mirrorTimes[all[i].k]
                }
            }
        }

        function handleNotification(notif) {
            if (dnd) return
            if (isContentless(notif)) return

            if (!timesLoaded) {
                pendingNotifs = pendingNotifs.concat([notif])
                return
            }

            var key = notifKey(notif)
            if (timesByKey[key] !== undefined
                && Date.now() - startupTime < 5000) {
                notif.tracked = false
                return
            }

            // Cross-app mirror (Ferdium + KDE Connect relay of the same
            // message): same sender + same core within mirrorWindowSec from
            // a different app collapses to the first arrival. Dropped here
            // means no popup, no sound, no DB row for the duplicate.
            if (isMirror(notif)) {
                notif.tracked = false
                return
            }

            notif.tracked = true
            addNotifTime(notif)
            rememberMirror(notif)
            activeNotifs = activeNotifs.concat([notif])
            count = activeNotifs.length
            tryPlaySound()
            newNotification(notif)
            // Debounce: bursts of notifications otherwise reload the whole
            // history table per message. markRead/delete paths still call
            // refreshHistory() synchronously for immediate UX.
            historyRefreshTimer.restart()

            notif.closed.connect(function(reason) {
                var arr = activeNotifs
                for (var i = 0; i < arr.length; i++) {
                    if (arr[i].id === notif.id) {
                        arr = arr.slice(0, i).concat(arr.slice(i + 1))
                        activeNotifs = arr
                        count = arr.length
                        break
                    }
                }
            })
        }

        function flushPending() {
            var pending = pendingNotifs
            pendingNotifs = []
            for (var i = 0; i < pending.length; i++)
                handleNotification(pending[i])
        }

        function addNotifTime(notif) {
            var key = notifKey(notif)
            var t = Date.now() / 1000
            notifTimes[notif.id] = t
            timesByKey[key] = t
            if (Object.keys(timesByKey).length > 200) pruneTimes(t - 10)
            var entry = {
                appName: notif.appName || "",
                summary: notif.summary || "",
                body: notif.body || "",
                urgency: notif.urgency || 1,
                appIcon: notif.appIcon || "",
                desktopEntry: notif.desktopEntry || "",
                expireTimeout: notif.expireTimeout || 0,
                actions: (notif.actions || []).map(function(a) {
                    return { text: a.text, identifier: a.identifier }
                }),
                timestamp: t
            }
            var newId = Db.insertNotification(entry)
            if (newId !== undefined && newId !== null) notif._dbId = newId
        }

        function toggleDnd() {
            dnd = !dnd
        }

        function clearAll() {
            var notifs = activeNotifs
            activeNotifs = []
            count = 0
            for (var i = 0; i < notifs.length; i++) {
                // Clear = done: mark the backing DB row read so the row lands in
                // Read after its live entry goes away, not back under Unread.
                if (notifs[i]._dbId !== undefined && notifs[i]._dbId !== null)
                    Db.markRead(notifs[i]._dbId)
                notifs[i].dismiss()
            }
            // Clear All also moves every unread history row into Read (the
            // merged Unread section now holds live + unread history).
            Db.markAllRead()
            refreshHistory()
        }

        // --- persistence (SQLite via qs.common Db) ---

        function loadSaved() {
            // Drop previously persisted contentless entries (older rows may
            // predate the ingest filter). The DB is the single source of truth.
            var data = Db.loadNotifications().filter(function(d) {
                return !notifData.isContentless(d)
            })
            var map = {}
            for (var i = 0; i < data.length; i++) {
                var d = data[i]
                map[notifData.notifKey(d)] = d.timestamp || 0
            }
            notifData.timesByKey = map
            console.log("notifData: loaded", data.length, "saved notifs,", Object.keys(map).length, "timestamps")
            notifData.timesLoaded = true
            refreshHistory()
        }

        function refreshHistory() {
            notifData.history = Db.loadHistory()
            console.log("notifData: loaded", notifData.history.length, "history rows (",
                notifData.history.filter(function(r) { return r.read !== 1 }).length, "unread)")
        }

        // Mark a single notification read. Accepts a live notif object (uses
        // its _dbId), a history row (uses .id), or a raw DB id.
        function markRead(target) {
            if (target === null || target === undefined) return
            var id = -1
            if (typeof target === "object") {
                if (target._dbId !== undefined && target._dbId !== null) id = target._dbId
                else if (target.id !== undefined && target.id !== null) id = target.id
            } else {
                id = target
            }
            if (id === -1 || id === null) return
            Db.markRead(id)
            // Reload from the DB with fresh array/object references so the
            // panel's Unread/Read groups reconcile reactively. Mutating the
            // existing array in place and reassigning the same reference would
            // not trigger a QML change notification.
            refreshHistory()
        }

        function markAllRead() {
            Db.markAllRead()
            refreshHistory()
        }

        // Delete one history row (history card dismiss).
        function deleteHistoryRow(id) {
            if (id === undefined || id === null) return
            Db.deleteHistoryRow(id)
            refreshHistory()
        }

        // Wipe only the read rows (Read group "Clear read").
        function clearRead() {
            Db.deleteRead()
            refreshHistory()
        }

        // Wipe all history (full clear).
        function clearHistory() {
            Db.deleteHistory()
            refreshHistory()
        }

        Timer {
            id: historyRefreshTimer
            interval: 400
            onTriggered: notifData.refreshHistory()
        }

        Process {
            id: soundProc
            command: [theme.scriptDir + "/notification-sound.sh"]
        }

        function tryPlaySound() {
            var now = Date.now()
            if (now - lastSoundTime < 1000) return
            lastSoundTime = now
            soundProc.running = true
        }
    }

    // ── CPU / RAM / GPU / Temp ──────────────────────────────

    Item {
        id: cpuData
        property int cpuUsage: 0
        property int ramUsage: 0
        property int swapUsage: 0
        property int gpuUsage: 0
        property int cpuTemp: 0
        property bool _parseWarned: false

        Process {
            id: sysFetchProc
            command: [Quickshell.env("HOME") + "/.cargo/bin/sys-stats"]

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        var data = JSON.parse(this.text.trim());
                        if (!isNaN(data.cpu)) cpuData.cpuUsage = data.cpu;
                        if (!isNaN(data.ram)) cpuData.ramUsage = data.ram;
                        if (!isNaN(data.swap)) cpuData.swapUsage = data.swap;
                        if (!isNaN(data.gpu)) cpuData.gpuUsage = data.gpu;
                        if (!isNaN(data.cpu_temp)) cpuData.cpuTemp = data.cpu_temp;
                    } catch (e) {
                        // Warn once per failure mode instead of spamming every
                        // 2s poll. Include the raw payload (truncated) so a bad
                        // sys-stats build is diagnosable.
                        if (!cpuData._parseWarned) {
                            cpuData._parseWarned = true
                            var raw = this.text ? this.text.trim() : ""
                            if (raw.length > 120) raw = raw.substring(0, 120) + "..."
                            console.warn("cpuData: sys-stats JSON parse failed:", e, "raw:", raw)
                        }
                    }
                }
            }
        }

        Timer {
            interval: 2000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (!sysFetchProc.running) sysFetchProc.running = true;
            }
        }
    }

    // ── Network Speed ───────────────────────────────────────

    Item {
        id: netData
        property string dlText: "--"
        property string ulText: "--"

        Process {
            id: netFetchProc
            command: [Quickshell.env("HOME") + "/.cargo/bin/net-stats"]

            stdout: StdioCollector {
                onStreamFinished: {
                    var output = this.text.trim();
                    if (!output) {
                        netData.dlText = "--";
                        netData.ulText = "--";
                    } else {
                        var parts = output.split("|")
                        if (parts.length >= 2) {
                            netData.dlText = parts[0] || "--";
                            netData.ulText = parts[1] || "--";
                        }
                    }
                }
            }
        }

        Timer {
            interval: 2000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (!netFetchProc.running) netFetchProc.running = true;
            }
        }
    }

    // ── Weather ─────────────────────────────────────────────

    Item {
        id: weatherData
        property string weatherIcon: ""
        property string weatherText: ""

        function refresh() {
            if (!weatherFetchProc.running) weatherFetchProc.running = true;
        }

        Process {
            id: weatherFetchProc
            command: [theme.scriptDir + "/weather.sh"]

            stdout: StdioCollector {
                onStreamFinished: {
                    var output = this.text.trim();
                    if (!output) return;
                    var outputs = output.split(/\s+/);
                    // Only update on valid data — stale value beats "--" for 30 min
                    if (outputs.length >= 2 && outputs[1] !== "--") {
                        weatherData.weatherIcon = outputs[0];
                        weatherData.weatherText = outputs[1];
                    }
                }
            }
        }

        Timer {
            interval: 1800000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (!weatherFetchProc.running) weatherFetchProc.running = true;
            }
        }
    }

    // ── Volume ──────────────────────────────────────────────

    Item {
        id: volumeData
        property int volumeLevel: 0
        property bool muted: false
        property string defaultSink: ""
        property var _notifyCmd: []
        property var _pendingNotifyCmd: []
        // True while an explicit cycleSink() is in flight. Suppresses the poll's
        // sink-change notify so a cycle never produces two popups (the script
        // already notifies itself once).
        property bool _cycling: false

        function refresh() {
            if (!volumeFetchProc.running) volumeFetchProc.running = true;
        }

        function cycleSink() {
            if (!cycleProc.running) {
                volumeData._cycling = true
                cycleProc.running = true
            }
        }

        Process {
            id: volumeFetchProc
            command: [theme.scriptDir + "/volume-status.sh"]

            stdout: StdioCollector {
                onStreamFinished: {
                    var output = this.text.trim();
                    var parts = output.split(" ");
                    if (parts.length >= 2) {
                        var vol = parseInt(parts[0]);
                        if (!isNaN(vol)) volumeData.volumeLevel = vol;
                        volumeData.muted = parts[1] === "true";
                    }
                    if (parts.length >= 3) {
                        var sink = parts[2];
                        // Notify on external switches too (panel/hotkey/Bluetooth).
                        // Cycle path notifies itself immediately; poll catches the rest.
                        if (volumeData.defaultSink !== "" && sink !== ""
                            && sink !== volumeData.defaultSink && sink !== "none"
                            && !volumeData._cycling) {
                            var notifyCmd = [theme.scriptDir + "/audio-notify.sh", sink];
                            if (!switchNotifyProc.running) {
                                volumeData._notifyCmd = notifyCmd;
                                switchNotifyProc.running = true;
                            } else {
                                volumeData._pendingNotifyCmd = notifyCmd;
                            }
                        }
                        if (sink !== "") volumeData.defaultSink = sink;
                    }
                }
            }
        }

        Process {
            id: cycleProc
            command: [theme.scriptDir + "/audio-cycle.sh"]
            stdout: StdioCollector {
                onStreamFinished: {
                    // Script notifies itself; sync baseline so the 5s poll stays silent
                    var sink = this.text.trim().split("\n").filter(function (l) { return l !== ""; }).pop() || "";
                    if (sink !== "") volumeData.defaultSink = sink;
                    volumeData._cycling = false;
                }
            }
            onRunningChanged: {
                if (!running) {
                    // Stream handler normally ran already and synced the
                    // baseline; only clear the gate here if there was no output.
                    if (volumeData._cycling) volumeData._cycling = false;
                    volumeData.refresh();
                }
            }
        }

        Process {
            id: switchNotifyProc
            command: volumeData._notifyCmd
            onRunningChanged: {
                if (!running && volumeData._pendingNotifyCmd.length > 0) {
                    volumeData._notifyCmd = volumeData._pendingNotifyCmd;
                    volumeData._pendingNotifyCmd = [];
                    running = true;
                }
            }
        }

        // Event-driven refresh for external changes (volume knob, hotkeys, apps).
        // Poll below stays as safety net only.
        Process {
            id: volumeSubscribeProc
            command: ["stdbuf", "-oL", "pactl", "subscribe"]
            running: true

            stdout: SplitParser {
                onRead: data => {
                    if (data.includes("on sink") || data.includes("on server"))
                        volumeData.refresh();
                }
            }

            onRunningChanged: {
                if (!running) subscribeRestartTimer.restart();
            }
        }

        Timer {
            id: subscribeRestartTimer
            interval: 1000
            onTriggered: {
                if (!volumeSubscribeProc.running) volumeSubscribeProc.running = true;
            }
        }

        Timer {
            interval: 5000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (!volumeFetchProc.running) volumeFetchProc.running = true;
            }
        }
    }

    // ── Battery ─────────────────────────────────────────────

    Item {
        id: batteryData
        property string batteryIcon: ""
        property string batteryStatus: ""

        Process {
            id: batteryFetchProc
            command: [theme.scriptDir + "/battery.sh"]

            stdout: StdioCollector {
                onStreamFinished: {
                    var output = this.text.trim()
                    if (!output) {
                        batteryData.batteryIcon = ""
                        batteryData.batteryStatus = ""
                    } else {
                        var parts = output.split("|")
                        if (parts.length >= 3) {
                            batteryData.batteryIcon = parts[0] || ""
                            batteryData.batteryStatus = parts[2] || ""
                        }
                    }
                }
            }
        }

        Timer {
            interval: 30000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (!batteryFetchProc.running) batteryFetchProc.running = true;
            }
        }
    }
}
