import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland._Ipc
import Quickshell.Hyprland._GlobalShortcuts
import Quickshell.Io
import QtQuick
import qs.common

// MRU window switcher. Hyprland drives it (lua/keybinds.lua):
//   ALT+Tab        -> quickshell:alttabNext + enter "alttab" submap
//   ALT+SHIFT+Tab  -> quickshell:alttabPrev
//   release Alt_L  -> quickshell:alttabCommit + submap reset
//   ALT+Escape     -> quickshell:alttabCancel + submap reset
// The overlay never takes keyboard focus; key handling stays in the compositor,
// so a crashed/reloading shell can't swallow the keyboard.
Scope {
    id: root

    property Theme theme: Theme {}

    // Own MRU list of window addresses (no "0x" prefix), most recent first.
    // Hyprland's focusHistoryID is only used once to seed it at startup.
    property var mru: []

    property bool open: false
    property bool shown: false          // UI visible (after short hold delay)
    property var entries: []            // snapshot taken when switcher opens
    property int index: 0

    // Visual constants
    readonly property int showDelayMs: 120
    readonly property int tileW: 132
    readonly property int tileH: 120
    readonly property int pad: 12
    readonly property int spacing: 8
    readonly property int radius: 16
    readonly property int tileRadius: 12
    readonly property int borderWidth: 1
    readonly property int selectedBorderWidth: 2
    readonly property int iconSize: 48
    readonly property int columnSpacing: 6
    readonly property int contentMargin: 16
    readonly property real maxWidthRatio: 0.85
    readonly property int fontSizeDelta1: 1
    readonly property int fontSizeDelta2: 2

    function norm(addr) {
        return String(addr || "").replace(/^0x/, "").toLowerCase()
    }

    function touch(addr) {
        var a = norm(addr)
        if (!a) return
        var next = mru.filter(x => x !== a)
        next.unshift(a)
        mru = next
    }

    function snapshot() {
        var tls = Hyprland.toplevels.values
        var byAddr = {}
        for (var i = 0; i < tls.length; i++) byAddr[norm(tls[i].address)] = tls[i]

        var out = []
        var seen = {}
        for (var j = 0; j < mru.length; j++) {
            var t = byAddr[mru[j]]
            if (t) { out.push(t); seen[mru[j]] = true }
        }
        // Windows never focused since shell start go last.
        for (var k = 0; k < tls.length; k++) {
            if (!seen[norm(tls[k].address)]) out.push(tls[k])
        }
        return out
    }

    function step(dir) {
        if (!open) {
            entries = snapshot()
            if (entries.length === 0) return
            // First press selects the previous window (index 1).
            index = entries.length > 1 ? (dir > 0 ? 1 : entries.length - 1) : 0
            open = true
            showDelay.restart()
            return
        }
        if (entries.length === 0) return
        index = (index + dir + entries.length) % entries.length
    }

    function close() {
        open = false
        shown = false
        showDelay.stop()
        entries = []
    }

    function focusEntry(t) {
        var a = norm(t?.address)
        if (!/^[0-9a-f]+$/.test(a)) return
        Hyprland.dispatch('hl.dsp.focus({ window = "address:0x' + a + '" })')
        Hyprland.dispatch('hl.dsp.window.bring_to_top()')
    }

    function commit() {
        if (!open) return
        var t = entries[index]
        close()
        if (t) focusEntry(t)
    }

    // Mouse pick: the click handler's delegate dies in close(), so do it all here.
    function pick(i) {
        index = i
        Hyprland.dispatch('hl.dsp.submap("reset")')
        commit()
    }

    // Quick Alt+Tab tap flips windows without flashing the overlay.
    Timer {
        id: showDelay
        interval: root.showDelayMs
        onTriggered: if (root.open) root.shown = true
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            if (Hyprland.activeToplevel) root.touch(Hyprland.activeToplevel.address)
        }
    }

    Process {
        id: seed
        running: true
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var clients = JSON.parse(text)
                    clients.sort((a, b) => b.focusHistoryID - a.focusHistoryID)
                    var seeded = clients.map(c => root.norm(c.address))
                    // Keep anything focused while the seed was running in front.
                    root.mru = root.mru.concat(seeded.filter(a => root.mru.indexOf(a) < 0))
                } catch (e) {
                    console.warn("alttab: seed failed:", e)
                }
            }
        }
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "alttabNext"
        description: "Alt-Tab: next window"
        onPressed: root.step(1)
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "alttabPrev"
        description: "Alt-Tab: previous window"
        onPressed: root.step(-1)
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "alttabCommit"
        description: "Alt-Tab: focus selected window"
        // Dispatched from a release bind, Hyprland sends only "released".
        onReleased: root.commit()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "alttabCancel"
        description: "Alt-Tab: cancel"
        onPressed: root.close()
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: root.shown
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-alttab"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        implicitWidth: Math.min(root.maxWidthRatio * (screen?.width ?? 1920), root.entries.length * (root.tileW + root.spacing) - root.spacing + root.pad * 2)
        implicitHeight: root.tileH + root.pad * 2

        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: root.theme.color
            border.color: root.theme.surface1
            border.width: root.borderWidth

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: root.pad
                orientation: ListView.Horizontal
                spacing: root.spacing
                clip: true
                interactive: false
                model: root.entries
                currentIndex: root.index
                highlightMoveDuration: 0
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: root.tileW
                preferredHighlightEnd: width - root.tileW

                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool selected: tile.index === root.index

                    width: root.tileW
                    height: root.tileH
                    radius: root.tileRadius
                    color: selected ? root.theme.surface1 : (hover.containsMouse ? root.theme.surface0 : "transparent")
                    border.color: selected ? root.theme.lavender : "transparent"
                    border.width: root.selectedBorderWidth

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - root.contentMargin
                        spacing: root.columnSpacing

                        AppIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            appId: tile.modelData.wayland?.appId || tile.modelData.lastIpcObject?.class || ""
                            size: root.iconSize
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: tile.modelData.title || tile.modelData.wayland?.appId || "?"
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            color: tile.selected ? root.theme.text : root.theme.subtext0
                            font.family: root.theme.font
                            font.pixelSize: root.theme.fontSize - root.fontSizeDelta1
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.workspace ? "[ " + tile.modelData.workspace.name + " ]" : ""
                            color: root.theme.subtext0
                            font.family: root.theme.font
                            font.pixelSize: root.theme.fontSize - root.fontSizeDelta2
                        }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.pick(tile.index)
                    }
                }
            }
        }
    }
}
