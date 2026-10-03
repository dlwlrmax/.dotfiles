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
            command: ["bash", theme.scriptDir + "/kdeconnect.sh"]

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
                for (var i = 0; i < notifs.length; i++) {
                    if (notifs[i].id !== nid) kept.push(notifs[i])
                    else { changed = true; stampSuppressed(nid) }
                }
                if (changed) {
                    var copy = {}
                    for (var k in dev) copy[k] = dev[k]
                    copy.notifications = kept
                    copy.notifCount = kept.length
                    devs = devs.slice(0, d).concat([copy]).concat(devs.slice(d + 1))
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
                for (var i = 0; i < notifs.length; i++) {
                    if (!notifs[i].dismissable) kept.push(notifs[i])
                    else { changed = true; stampSuppressed(notifs[i].id) }
                }
                if (changed) {
                    var copy = {}
                    for (var k in dev) copy[k] = dev[k]
                    copy.notifications = kept
                    copy.notifCount = kept.length
                    devs = devs.slice(0, d).concat([copy]).concat(devs.slice(d + 1))
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
        property var history: []
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

        function requestDismissPopup(notifId) {
            dismissPopup(notifId)
        }

        function notifHash(notif) {
            var s = (notif.appName || "") + "|" + (notif.summary || "") + "|" + (notif.body || "")
            var h = 0
            for (var i = 0; i < s.length; i++) {
                h = ((h << 5) - h) + s.charCodeAt(i)
                h |= 0
            }
            return "" + h
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

        function handleNotification(notif) {
            if (dnd) return
            if (isContentless(notif)) return

            if (!timesLoaded) {
                pendingNotifs = pendingNotifs.concat([notif])
                return
            }

            var key = notifHash(notif)
            if (timesByKey[key] !== undefined
                && Date.now() - startupTime < 5000) {
                notif.tracked = false
                return
            }

            notif.tracked = true
            addNotifTime(notif)
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
            var key = notifHash(notif)
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
                var s = (d.appName || "") + "|" + (d.summary || "") + "|" + (d.body || "")
                var h = 0
                for (var j = 0; j < s.length; j++) {
                    h = ((h << 5) - h) + s.charCodeAt(j)
                    h |= 0
                }
                map["" + h] = d.timestamp || 0
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
            command: ["bash", theme.scriptDir + "/notification-sound.sh"]
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

        Process {
            id: sysFetchProc
            command: ["bash", theme.scriptDir + "/sys-data.sh"]

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        var data = JSON.parse(this.text.trim());
                        if (!isNaN(data.cpu)) cpuData.cpuUsage = data.cpu;
                        if (!isNaN(data.ram)) cpuData.ramUsage = data.ram;
                        if (!isNaN(data.swap)) cpuData.swapUsage = data.swap;
                        if (!isNaN(data.gpu)) cpuData.gpuUsage = data.gpu;
                        if (!isNaN(data.cpu_temp)) cpuData.cpuTemp = data.cpu_temp;
                    } catch (e) {}
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
            command: ["bash", theme.scriptDir + "/net-data.sh"]

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
            command: ["bash", theme.scriptDir + "/weather.sh"]

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

        function refresh() {
            if (!volumeFetchProc.running) volumeFetchProc.running = true;
        }

        function cycleSink() {
            if (!cycleProc.running) cycleProc.running = true;
        }

        Process {
            id: volumeFetchProc
            command: ["bash", theme.scriptDir + "/volume-status.sh"]

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
                            && sink !== volumeData.defaultSink && sink !== "none") {
                            var notifyCmd = ["bash", theme.scriptDir + "/audio-notify.sh", sink];
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
            command: ["bash", theme.scriptDir + "/audio-cycle.sh"]
            stdout: StdioCollector {
                onStreamFinished: {
                    // Script notifies itself; sync baseline so the 5s poll stays silent
                    var sink = this.text.trim().split("\n").filter(function (l) { return l !== ""; }).pop() || "";
                    if (sink !== "") volumeData.defaultSink = sink;
                }
            }
            onRunningChanged: {
                if (!running) volumeData.refresh();
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
            command: ["bash", theme.scriptDir + "/battery.sh"]

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
