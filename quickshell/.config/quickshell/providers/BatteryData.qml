// BatteryData
// Battery devices from /sys/class/power_supply (laptop pack, mouse, headset, ...).
// Keeps a short capacity history per device for the time-remaining estimate and
// posts one notification when a discharging device gets low.
import Quickshell
import Quickshell.Io
import QtQuick
import qs.common

Item {
    id: root
    property Theme theme: ThemeStore

    property var devices: []
    // name -> [{t: epoch s, c: capacity %}] (numeric capacities only), newest last
    property var history: ({})
    property int historyTick: 0
    // names already notified for the current discharge
    property var _warned: ({})

    readonly property int lowPct: 20
    readonly property int criticalPct: 10
    readonly property int maxSamples: 90

    // Device to show in the bar: the lowest one that is charging or running low.
    readonly property var attention: {
        var best = null
        for (var i = 0; i < devices.length; i++) {
            var d = devices[i]
            if (!isLow(d) && d.status !== "Charging") continue
            if (best === null || level(d) < level(best)) best = d
        }
        return best
    }

    function level(d) {
        if (typeof d.capacity === "number") return d.capacity
        var l = d.capacity_level
        return l === "Full" ? 100 : l === "Normal" ? 66 : l === "Low" ? 25 : l === "Critical" ? 5 : 50
    }

    function isLow(d) {
        return d.status !== "Charging" && (d.capacity_level === "Low" || d.capacity_level === "Critical"
               || (typeof d.capacity === "number" && d.capacity <= lowPct))
    }

    function label(d) { return d.model || d.name || "Battery" }

    // Minutes until empty at the recent discharge rate; -1 when unknown.
    function minutesLeft(d) {
        historyTick
        var h = history[d.name]
        if (!h || h.length < 2 || d.status !== "Discharging" || typeof d.capacity !== "number") return -1
        var first = h[0], last = h[h.length - 1]
        var dt = (last.t - first.t) / 60, dc = first.c - last.c
        if (dt < 8 || dc < 1) return -1
        return Math.round(last.c / (dc / dt))
    }

    function fmtMinutes(m) {
        if (m < 0) return ""
        var h = Math.floor(m / 60), mm = m % 60
        return h > 0 ? h + "h " + mm + "m" : mm + "m"
    }

    function refresh() {
        if (!fetchProc.running) fetchProc.running = true
    }

    function _ingest(list) {
        var h = Object.assign({}, history), now = Math.floor(Date.now() / 1000)
        for (var i = 0; i < list.length; i++) {
            var d = list[i]
            if (typeof d.capacity === "number" && d.status !== "Discharging") {
                delete h[d.name]    // charging/full plateaus must not stretch the discharge slope
            } else if (typeof d.capacity === "number") {
                var arr = (h[d.name] || []).slice()
                // A charge restarts the discharge curve.
                if (arr.length && d.capacity > arr[arr.length - 1].c + 1) arr = []
                arr.push({ t: now, c: d.capacity })
                while (arr.length > maxSamples) arr.shift()
                h[d.name] = arr
            }
            // low-battery notification, once per discharge
            if (isLow(d)) {
                var tier = (d.capacity_level === "Critical" || (typeof d.capacity === "number" && d.capacity <= criticalPct)) ? 2 : 1
                if ((_warned[d.name] || 0) < tier && Prefs.show("battery")) {
                    var w = Object.assign({}, _warned); w[d.name] = tier; _warned = w
                    Quickshell.execDetached(["notify-send", "-u", tier === 2 ? "critical" : "normal", "-a", "Battery",
                        label(d) + (tier === 2 ? " is critically low" : " is low"),
                        typeof d.capacity === "number" ? d.capacity + "% remaining" : d.capacity_level])
                }
            } else if (_warned[d.name] && (d.status === "Charging" || d.capacity_level === "Full" || level(d) > lowPct + 10)) {
                var w2 = Object.assign({}, _warned); delete w2[d.name]; _warned = w2
            }
        }
        history = h
        historyTick++
        devices = list
    }

    Process {
        id: fetchProc
        command: ["bash", theme.scriptDir + "/battery-all.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root._ingest(JSON.parse(this.text).devices || []) }
                catch (e) { console.log("BatteryData: parse error", e) }
            }
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
