// HealthData
// Collects problems from the other providers so the shell can say when something
// is wrong (weather unreachable, KDE Connect down, no network, missing packages).
import Quickshell
import Quickshell.Io
import QtQuick
import qs.common

Item {
    id: root
    property Theme theme: ThemeStore

    // Providers to inspect (set by DataProviders).
    property var weather: null
    property var kde: null
    property var net: null
    property var cpu: null

    // Missing packages from scripts/check-deps.sh --list: [{pkg, kind, desc}]
    property var missingDeps: []
    // Unstowed/broken configs from scripts/check-configs.sh --list: [{pkg, kind, desc}]
    property var badConfigs: []
    // True while scripts/stow-configs.sh is putting the broken configs in place.
    property bool fixingConfigs: false

    // [{id, title, detail, level: "warn"|"error"}] ordered by severity
    readonly property var issues: {
        _tick   // re-evaluate time-based checks
        var out = []
        if (weather && weather.error !== "") {
            out.push({ id: "weather", level: weather.error === "network" ? "warn" : "error",
                       title: "Weather", detail: weather.errorMessage || "Weather unavailable" })
        }
        if (kde && !kde.daemonUp)
            out.push({ id: "kde", level: "warn", title: "KDE Connect", detail: "kdeconnectd is not running" })
        if (net && !net.connected)
            out.push({ id: "net", level: "error", title: "Network", detail: "No active network interface" })
        if (statsStale)
            out.push({ id: "stats", level: "warn", title: "System stats", detail: "sys-stats has stopped updating" })
        for (var i = 0; i < missingDeps.length; i++) {
            var d = missingDeps[i]
            out.push({ id: "dep:" + d.pkg, level: d.kind === "required" ? "error" : "warn",
                       title: "Missing package: " + d.pkg, detail: d.desc })
        }
        for (var i = 0; i < badConfigs.length; i++) {
            var c = badConfigs[i]
            out.push({ id: "cfg:" + c.pkg, level: c.kind === "required" ? "error" : "warn",
                       title: "Config not healthy: " + c.pkg, detail: c.desc })
        }
        out.sort(function (a, b) { return (b.level === "error") - (a.level === "error") })
        return out
    }
    // Stale-stats check lives apart from `issues` so a fresh CPU sample (every 2s) does not
    // rebuild the issue list: it re-evaluates only on the slow tick.
    readonly property bool statsStale: {
        _tick
        return !!cpu && cpu.updatedAt > 0 && Date.now() / 1000 - cpu.updatedAt > Math.max(30, cpu.statPollMs / 100)
    }
    readonly property int count: issues.length
    readonly property bool hasErrors: issues.some(function (x) { return x.level === "error" })

    // Re-evaluates the time-based checks (stale stats) now and then.
    property int _tick: 0
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root._tick++ }

    function checkDeps() {
        if (!depsProc.running) depsProc.running = true
    }

    function checkConfigs() {
        if (!configsProc.running) configsProc.running = true
    }

    // One-click fix for badConfigs: stows the broken packages, then re-checks
    // so the warnings clear on their own.
    function fixConfigs() {
        if (fixConfigsProc.running) return
        fixingConfigs = true
        fixConfigsProc.running = true
    }

    Process {
        id: depsProc
        command: ["bash", theme.scriptDir + "/check-deps.sh", "--list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = this.text.split("\n"), out = []
                for (var i = 0; i < rows.length; i++) {
                    var f = rows[i].split("\t")
                    if (f.length >= 2 && f[0] && f[1] !== "setup") out.push({ pkg: f[0], kind: f[1], desc: f[2] || "" })
                }
                root.missingDeps = out
            }
        }
    }

    Process {
        id: configsProc
        command: ["bash", theme.scriptDir + "/check-configs.sh", "--list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = this.text.split("\n"), out = []
                for (var i = 0; i < rows.length; i++) {
                    var f = rows[i].split("\t")
                    if (f.length >= 2 && f[0]) out.push({ pkg: f[0], kind: f[1], desc: f[2] || "" })
                }
                root.badConfigs = out
            }
        }
    }

    Process {
        id: fixConfigsProc
        command: ["bash", theme.scriptDir + "/stow-configs.sh"]
        stdout: StdioCollector {
            // Output is not parsed; we only need to know the fixer finished,
            // then re-check so the issue list reflects the stowed state.
            onStreamFinished: {
                root.fixingConfigs = false
                root.checkConfigs()
            }
        }
    }

    // First check shortly after startup, then hourly.
    Timer { interval: 20000; running: true; onTriggered: { root.checkDeps(); root.checkConfigs() } }
    Timer { interval: 3600000; running: true; repeat: true; onTriggered: { root.checkDeps(); root.checkConfigs() } }
}
