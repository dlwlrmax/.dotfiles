pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Generated palette (named ShellPalette: QtQuick already has a Palette type) (scripts/palette.py -> ~/.cache/quickshell/palette.json).
// Theme reads every colour through get(): the generated value while the theme
// mode is "wallpaper" and the file has it, otherwise the built-in Catppuccin default.
Singleton {
    id: palette

    readonly property string file: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/quickshell/palette.json"

    // name -> "#rrggbb" from the file ({} until loaded)
    property var colors: ({})
    // Wallpaper the palette was generated from ("" when none).
    property string source: ""
    readonly property bool available: Object.keys(colors).length > 0

    function get(name, fallback) {
        return Prefs.themeMode === "wallpaper" && colors[name] ? colors[name] : fallback
    }

    function _parse(text) {
        try {
            var d = JSON.parse(text)
            if (d && d.colors) { colors = d.colors; source = d.source || "" }
        } catch (e) {
            console.log("Palette: unreadable palette file:", e)
        }
    }

    FileView {
        path: palette.file
        printErrors: false   // absent until the first wallpaper palette is generated
        watchChanges: true
        onFileChanged: reload()
        onLoaded: palette._parse(text())
    }
}
