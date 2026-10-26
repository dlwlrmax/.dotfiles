pragma Singleton
import QtQuick

// Shell-wide flags that leaf components need without threading props through
// every parent. gamingMonitor is written by shell.qml; idleInhibit by the bar
// widget and the quick-controls panel.
QtObject {
    // Monitor the game is on while the gaming profile is active; "" when not gaming,
    // "*" when gaming but the monitor is unknown (blocks every screen).
    property string gamingMonitor: ""

    // Keep-awake toggle shared by the bar's idle-inhibitor widgets and the
    // quick-controls panel.
    property bool idleInhibit: false

    // Phone app name (lower-case) -> icon file, learnt from KDE Connect, so relayed
    // phone notifications can show the phone app's icon in the notification UI.
    property var phoneAppIcons: ({})

    // Link waiting for a browser choice (browserpick panel, scripts/link-open.sh):
    // [{pid, class, address, titles, profile, argv}], most recently focused first.
    property string linkUrl: ""
    property var linkBrowsers: []

    // True if popups/tooltips should stay off the given screen (QScreen/monitor name).
    function quietOn(screenName) {
        return gamingMonitor === "*" || (gamingMonitor !== "" && gamingMonitor === screenName)
    }

    // ── system tray pins ──
    // Ids of tray items kept in the bar. null = never customised (first 5 show).
    property var trayPins: null
    readonly property int trayDefaultVisible: 5
    property bool _trayLoaded: false

    function loadTrayPins() {
        if (_trayLoaded) return
        _trayLoaded = true
        var row = Db.cacheGet("traypins")
        if (!row) return
        try { var v = JSON.parse(row.json); if (Array.isArray(v)) trayPins = v } catch (e) {}
    }

    function trayShown(id, index) {
        return trayPins === null ? index < trayDefaultVisible : trayPins.indexOf(id) >= 0
    }

    function setTrayPinned(id, pinned, allIds) {
        // First customisation starts from what is visible now.
        var cur = trayPins === null
            ? allIds.filter(function (x, i) { return i < trayDefaultVisible })
            : trayPins.slice()
        var at = cur.indexOf(id)
        if (pinned && at < 0) cur.push(id)
        if (!pinned && at >= 0) cur.splice(at, 1)
        trayPins = cur
        Db.cachePut("traypins", JSON.stringify(cur))
    }
}
