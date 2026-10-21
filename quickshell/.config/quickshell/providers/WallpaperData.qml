// WallpaperData
// The current wallpaper, the wallpaper folder, and the palette that follows it.
// Wallpapers are set through waypaper (hyprpaper backend), so your usual
// waypaper workflow keeps working; this provider notices changes by polling.
import Quickshell
import Quickshell.Io
import QtQuick
import qs.common

Item {
    id: root
    property Theme theme: ThemeStore

    property string current: ""
    property string folder: ""
    // [{path, name, thumb}] sorted by name
    property var items: []
    // Bumped when new thumbnails are on disk, so images reload.
    property int thumbVersion: 0
    property bool thumbsBusy: false
    property bool generating: false

    readonly property string script: theme.scriptDir + "/wallpaper.sh"

    function nameOf(path) { return path.split("/").pop().replace(/\.[^.]+$/, "") }

    function refreshCurrent() {
        if (!curProc.running) curProc.running = true
    }

    function loadList() {
        if (!listProc.running) listProc.running = true
    }

    property string _queuedSet: ""

    function set(path) {
        current = path                      // optimistic; the poll confirms
        if (setProc.running) { _queuedSet = path; return }   // run the latest click when this one ends
        setProc.command = ["bash", script, "set", path]
        setProc.running = true
    }

    function random() {
        setProc.command = ["bash", script, "random"]
        setProc.running = true
    }

    // Write the shell palette for the current wallpaper (cached per image).
    function regenerate() {
        if (genProc.running || current === "") return
        generating = true
        genProc.path = current
        genProc.command = ["bash", script, "palette", current]
        genProc.running = true
    }

    // Wallpaper mode needs a palette that matches the wallpaper.
    function ensurePalette() {
        if (Prefs.themeMode !== "wallpaper" || current === "") return
        if (!ShellPalette.available || (Prefs.autoFollow && ShellPalette.source !== current)) regenerate()
    }

    onCurrentChanged: ensurePalette()

    // Learn the wallpaper once at startup even when nothing polls.
    Component.onCompleted: refreshCurrent()

    Connections {
        target: Prefs
        function onThemeModeChanged() { root.ensurePalette() }
        function onAutoFollowChanged() { root.ensurePalette() }
    }

    Process {
        id: curProc
        command: ["bash", root.script, "current"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim()
                if (p !== "" && p !== root.current) root.current = p
            }
        }
    }

    Process {
        id: folderProc
        command: ["bash", root.script, "folder"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.folder = this.text.trim() }
    }

    Process {
        id: listProc
        command: ["bash", root.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [], lines = this.text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var f = lines[i].split("\t")
                    if (f.length === 2) out.push({ path: f[0], name: root.nameOf(f[0]), thumb: f[1] })
                }
                root.items = out
                if (!thumbProc.running) { root.thumbsBusy = true; thumbProc.running = true }
            }
        }
    }

    Process {
        id: thumbProc
        command: ["bash", root.script, "thumbs"]
        onExited: { root.thumbsBusy = false; root.thumbVersion++ }
    }

    Process {
        id: setProc
        onExited: {
            if (root._queuedSet !== "") {
                var next = root._queuedSet
                root._queuedSet = ""
                setProc.command = ["bash", root.script, "set", next]
                setProc.running = true
                return
            }
            // hyprpaper applies it a moment later
            root.refreshCurrent()
            recheck.restart()
        }
    }

    Timer { id: recheck; interval: 900; onTriggered: root.refreshCurrent() }

    Process {
        id: genProc
        property string path: ""
        onExited: {
            root.generating = false
            // wallpaper changed while generating: go again
            if (genProc.path !== root.current) root.ensurePalette()
        }
    }

    // Notices wallpaper changes made elsewhere (waypaper GUI, scripts). Only needed while the
    // palette follows the wallpaper; the panel refreshes on open.
    Timer {
        interval: 5000
        running: Prefs.themeMode === "wallpaper" && Prefs.autoFollow
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshCurrent()
    }
}
