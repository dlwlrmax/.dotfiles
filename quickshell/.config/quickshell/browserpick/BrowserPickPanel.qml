import QtQuick
import Quickshell
import qs.common

// Which running browser gets a link opened from a terminal (scripts/link-open.sh
// fills ShellState.linkUrl / linkBrowsers and opens this panel over IPC).
// Enter opens it there and focuses that window; Shift+Enter opens it in the
// background. Esc drops the link.
Item {
    id: root

    property Theme theme: ThemeStore
    property bool active: false
    signal close()

    implicitWidth: picker.implicitWidth
    implicitHeight: picker.implicitHeight

    readonly property var names: ({
        "zen": "Zen", "firefox": "Firefox", "librewolf": "LibreWolf", "floorp": "Floorp",
        "waterfox": "Waterfox", "google-chrome": "Chrome", "google-chrome-beta": "Chrome Beta",
        "chromium": "Chromium", "brave-browser": "Brave", "vivaldi-stable": "Vivaldi",
        "microsoft-edge": "Edge", "opera": "Opera", "thorium-browser": "Thorium", "helium": "Helium"
    })

    function rebuild() {
        var q = picker.query.trim().toLowerCase()
        var out = []
        var list = ShellState.linkBrowsers || []
        for (var i = 0; i < list.length; i++) {
            var b = list[i]
            var title = (names[b.class] || b.class) + (b.profile ? " · " + b.profile : "")
            var sub = b.titles.length + (b.titles.length === 1 ? " window · " : " windows · ") + b.titles[0]
            if (q !== "" && (title + " " + b.titles.join(" ")).toLowerCase().indexOf(q) < 0) continue
            out.push({ kind: "browser", address: b.address, browser: b, title: title, subtitle: sub,
                       icon: { appId: b.class, fallbackGlyph: "󰖟" } })
        }
        if (q === "" || "copy".indexOf(q) >= 0)
            out.push({ kind: "copy", title: "Copy link", subtitle: ShellState.linkUrl, glyph: "󰆏" })
        picker.rows = out
    }

    function activate(row, alt) {
        if (row.kind === "copy") {
            Quickshell.execDetached(["wl-copy", ShellState.linkUrl])
        } else {
            Quickshell.execDetached({ command: row.browser.argv, workingDirectory: Quickshell.env("HOME") })
            if (!alt)
                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:" + row.address + "\" })"])
        }
        root.close()
    }

    onActiveChanged: {
        if (!active) return
        picker.reset()
        picker.query = ""
        rebuild()
        Qt.callLater(function () { picker.focusSearch() })
    }

    Connections {
        target: ShellState
        function onLinkBrowsersChanged() { if (root.active) root.rebuild() }
        function onLinkUrlChanged() { if (root.active) root.rebuild() }
    }

    PickerPanel {
        id: picker
        anchors.fill: parent
        theme: root.theme
        active: root.active
        placeholder: "Open " + (ShellState.linkUrl.length > 70 ? ShellState.linkUrl.substring(0, 69) + "…" : ShellState.linkUrl)
        rowHeight: 52
        iconSize: 30
        listWidth: 520
        // search + footer + margins, then the rows: no tall empty list for 2–3 browsers
        implicitHeight: Math.min(520, 104 + ((ShellState.linkBrowsers || []).length + 1) * (rowHeight + 2))
        hints: "↵ open + focus · ⇧↵ open in background · esc cancel"

        onQueryChanged: root.rebuild()
        onActivated: (row, alt) => root.activate(row, alt)
        onCloseRequested: root.close()
    }
}
