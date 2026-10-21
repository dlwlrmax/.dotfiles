pragma Singleton
import QtQuick

// User preferences edited in the Settings panel, persisted in the shell's cache
// table. Bar items default to visible; only hidden ones are stored.
QtObject {
    id: prefs

    // Name of a Theme palette colour used for highlights (today marker, play button, ...).
    property string accentName: "mauve"
    // Bar items the user turned off: key -> true.
    // Keys: mpris, stats, weather, volume, phone, battery, controls, idle, tray.
    property var hidden: ({})
    // CPU/RAM/net capsule on every bar instead of only the primary screen.
    property bool statsAllScreens: false
    // "catppuccin" (built-in palette) or "wallpaper" (generated from the wallpaper).
    property string themeMode: "catppuccin"
    // In wallpaper mode, regenerate the palette whenever the wallpaper changes.
    property bool autoFollow: true

    readonly property var accentChoices: ["auto", "mauve", "blue", "lavender", "sapphire", "sky", "green", "yellow", "peach", "pink", "red"]
    readonly property var barItems: [
        { key: "mpris",    label: "Now playing" },
        { key: "stats",    label: "CPU / RAM / network" },
        { key: "weather",  label: "Weather" },
        { key: "volume",   label: "Volume" },
        { key: "phone",    label: "Phone (KDE Connect)" },
        { key: "battery",  label: "Low battery alerts" },
        { key: "controls", label: "Settings button" },
        { key: "idle",     label: "Stay-awake toggle" },
        { key: "tray",     label: "System tray" }
    ]

    property bool _loaded: false

    function show(key) { return !hidden[key] }

    function setShown(key, shown) {
        var h = Object.assign({}, hidden)
        if (shown) delete h[key]; else h[key] = true
        hidden = h
        save()
    }

    function setAccent(name) { accentName = name; save() }
    function setStatsAllScreens(v) { statsAllScreens = v; save() }
    function setAutoFollow(v) { autoFollow = v; save() }

    // Switching to the wallpaper theme also picks the wallpaper's own highlight;
    // switching back restores the default accent if it was "auto".
    function setThemeMode(mode) {
        themeMode = mode
        if (mode === "wallpaper" && accentName === "mauve") accentName = "auto"
        if (mode !== "wallpaper" && accentName === "auto") accentName = "mauve"
        save()
    }

    // Called once from shell.qml (singleton Component.onCompleted does not fire reliably).
    function load() {
        if (_loaded) return
        var row = Db.cacheGet("prefs")
        if (row) {
            try {
                var p = JSON.parse(row.json)
                if (p.accentName && accentChoices.indexOf(p.accentName) >= 0) accentName = p.accentName
                if (p.hidden) hidden = p.hidden
                statsAllScreens = !!p.statsAllScreens
                if (p.themeMode === "wallpaper") themeMode = "wallpaper"
                autoFollow = p.autoFollow !== false
            } catch (e) {}
        }
        _loaded = true
    }

    function save() {
        if (!_loaded) return
        Db.cachePut("prefs", JSON.stringify({ accentName: accentName, hidden: hidden, statsAllScreens: statsAllScreens,
                                              themeMode: themeMode, autoFollow: autoFollow }))
    }

}
