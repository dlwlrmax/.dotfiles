// KdeData
// KDE Connect devices, notifications and phone icons.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import QtQuick
import qs.common

Item {
    id: kdeData
    property Theme theme: ThemeStore
    // Poll period; DataProviders slows it down while gaming.
    property int statPollMs: 2000
    property var devices: []
    property var device: devices.length > 0 ? devices[0] : null
    property bool anyConnected: false
    // False when kdeconnectd isn't on the session bus (panel offers to start it).
    property bool daemonUp: true
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

    property string _devicesSig: ""

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
            // A new array makes the panel recreate every card (losing reply drafts), so only
        // assign when something actually changed.
        var sig = JSON.stringify(filtered)
        if (sig === _devicesSig) return
        _devicesSig = sig
        kdeData.devices = filtered
    }

    // App name -> icon file, accumulated across polls and persisted so it
    // outlives the phone's notification list (and restarts).
    function learnIcons(devs) {
        var map = ShellState.phoneAppIcons, changed = false
        for (var d = 0; d < devs.length; d++) {
            var ns = devs[d].notifications || []
            for (var i = 0; i < ns.length; i++) {
                var n = ns[i]
                if (!n.appName || !n.iconPath) continue
                var k = n.appName.toLowerCase()
                if (map[k] !== n.iconPath) {
                    if (!changed) { map = Object.assign({}, map); changed = true }
                    map[k] = n.iconPath
                }
            }
        }
        if (changed) {
            ShellState.phoneAppIcons = map
            Db.cachePut("kdeicons", JSON.stringify(map))
        }
    }

    function loadIcons() {
        var row = Db.cacheGet("kdeicons")
        if (!row) return
        try { ShellState.phoneAppIcons = JSON.parse(row.json) } catch (e) {}
    }

    function applyJson(text) {
        try {
            var data = JSON.parse(text.trim())
            learnIcons(data.devices || [])
            applyDevices(data.devices || [])
            anyConnected = data.anyConnected || false
            daemonUp = data.daemon !== false
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

    // Safety-net poll only: kdeconnectd signals (below) drive updates.
    Timer {
        id: kdePollTimer
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: kdeData.poll()
    }

    // Event-driven refresh: any kdeconnectd signal (notification posted/
    // removed, battery, reachability) schedules one debounced fetch, so a
    // burst of signals costs a single python3 run.
    Process {
        id: kdeSignalProc
        command: ["dbus-monitor", "--session",
            "type='signal',path_namespace='/modules/kdeconnect'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data.startsWith("signal") && data.includes("path=/modules/kdeconnect"))
                    kdeSignalDebounce.restart()
            }
        }
        onRunningChanged: if (!running) kdeSignalRestart.restart()
    }

    Timer {
        id: kdeSignalDebounce
        interval: 300
        onTriggered: kdeData.refresh()
    }

    Timer {
        id: kdeSignalRestart
        interval: 5000
        onTriggered: if (!kdeSignalProc.running) kdeSignalProc.running = true
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
        _devicesSig = JSON.stringify(devs)
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
        _devicesSig = JSON.stringify(devs)
            Db.cacheInvalidate("kde")
            kdeData.refresh()
        }
    }

    Component.onCompleted: {
        loadIcons()
        poll()
    }
}
