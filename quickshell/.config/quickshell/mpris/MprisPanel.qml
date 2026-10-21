import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.common

Item {
    id: root
    property Theme theme: ThemeStore
    property bool active: false
    property int maxListHeight: 420
    signal close()

    // Filtered player list, rebuilt imperatively on model signals.
    // (Mpris.players is an UntypedObjectModel: rowCount() is NOT QML-callable
    // — QAbstractItemModel::rowCount is not invokable — so iterate the QObjectList
    // `values` property and rebuild on its valuesChanged notify.)
    // Rules: hide duplicates (bridge mirror) and title-less players
    // (e.g. idle Stremio/Chrome, whose artist placeholder is non-empty but
    // title is empty). Paused/stopped players WITH a real title stay —
    // user may resume them.
    property var playerModel: []
    function _rebuildPlayers() {
        var seen = []
        var out = []
        var players = Mpris.players.values || []
        for (var i = 0; i < players.length; i++) {
            var p = players[i]
            if (!p) continue
            if (!p.trackTitle) continue
            // Skip playerctld: it is a proxy mirror with no real data.
            // dbusName is the unique, constant bus address per player.
            // Fall back to identity when unavailable so a bridging mirror
            // (same identity, different bus name) is still collapsed.
            var bus = p.dbusName || ""
            if (bus.endsWith(".playerctld")) continue
            var id = bus || p.identity || ""
            if (seen.indexOf(id) !== -1) continue
            seen.push(id)
            out.push(p)
        }
        // Players emit dataChanged on every state/metadata update. Reassigning an
        // identical list would make the Repeater rebuild every delegate (tooltips,
        // sliders, animations); only swap when membership/order changed.
        var cur = root.playerModel
        var same = cur.length === out.length
        for (var k = 0; same && k < out.length; k++) same = cur[k] === out[k]
        if (!same) root.playerModel = out
    }

    // Durations (incl. remembered/yt-dlp fallbacks) come from MediaInfo.trackLength.
    Component.onCompleted: root._rebuildPlayers()
    Connections {
        target: Mpris.players
        function onRowsInserted() { root._rebuildPlayers() }
        function onRowsRemoved() { root._rebuildPlayers() }
        function onDataChanged() { root._rebuildPlayers() }
        function onModelReset() { root._rebuildPlayers() }
        // valuesChanged is the notify signal of the `values` QObjectList.
        function onValuesChanged() { root._rebuildPlayers() }
    }

    clip: true
    implicitWidth: theme.panelWidthS
    implicitHeight: (root.playerModel.length > 0 ? Math.min(playerList.implicitHeight, root.maxListHeight) : 60) + header.implicitHeight + 40

    PanelBackground {
        anchors.fill: parent
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        PanelHeader {
            id: header
            theme: root.theme
            title: "Media" + (root.playerModel.length > 0 ? " (" + root.playerModel.length + ")" : "")
            onClose: root.close()
        }

        ScrollView {
            id: playerScroll
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(playerList.implicitHeight, root.maxListHeight)
            clip: true
            visible: root.playerModel.length > 0
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                id: playerList
                width: playerScroll.availableWidth
                spacing: 10

                Repeater {
                    model: root.playerModel

                    PlayerCard {
                        required property var modelData
                        theme: root.theme
                        player: modelData
                        onFocusRequested: {
                            if (typeof modelData.raise === "function" && modelData.canRaise) modelData.raise()
                            else root.focusPlayer(modelData)
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 20
            Layout.bottomMargin: 20
            spacing: 10
            visible: root.playerModel.length === 0

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "No media players"
                color: theme.subtext0
                font.pixelSize: theme.fontSize
                font.family: theme.fontUi
            }

            Badge {
                Layout.alignment: Qt.AlignHCenter
                theme: root.theme
                text: "Open browser"
                clr: theme.blue
                clickable: true
                onClicked: defaultBrowserProc.running = true
            }
        }
    }

    // Derive a Hyprland window-class candidate from a player's identity.
    // Preference: desktopEntry basename, then identity, then dbusName tail.
    function playerClass(player) {
        if (!player) return ""
        var de = player.desktopEntry || ""
        if (de) {
            de = String(de).replace(/\.desktop$/i, "")
            var dot = de.lastIndexOf(".")
            if (dot >= 0) de = de.substring(dot + 1)
            if (de) return de
        }
        var id = player.identity || ""
        if (id) {
            id = String(id).split(" - ")[0].trim().toLowerCase().replace(/\s+/g, "")
            if (id) return id
        }
        var bus = player.dbusName || ""
        if (bus) {
            var tail = String(bus).split(".").pop()
            if (tail) return tail.toLowerCase()
        }
        return ""
    }

    function focusPlayer(player) {
        var cls = root.playerClass(player)
        if (cls.length === 0) return
        Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "class:" + cls])
    }

    // Empty state has no player to derive from, so open the system default
    // http handler (data-derived, no hardcoded browser name).
    Process {
        id: defaultBrowserProc
        command: ["xdg-mime", "query", "default", "x-scheme-handler/http"]
        stdout: StdioCollector {
            onStreamFinished: {
                var de = this.text.trim()
                if (de.length > 0) Quickshell.execDetached(["gtk-launch", de])
            }
        }
    }


    // Players change title/state without the model changing; re-filter while the panel is open.
    Timer {
        interval: 2000
        running: root.active
        repeat: true
        onTriggered: root._rebuildPlayers()
    }

    // Poll live positions only when the panel is open AND at least one player
    // exposes a usable time source: a real length, or (fallback) a live
    // position while playing (Zen/Firefox send position but no mpris:length).
    Timer {
        interval: 1000
        running: root.active && root.playerModel.some(function(p) {
            return p && (MediaInfo.trackLength(p) > 1
                || (p.isPlaying && p.positionSupported))
        })
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var players = Mpris.players.values || []
            for (var i = 0; i < players.length; i++) {
                var player = players[i]
                if (player && player.isPlaying && player.positionSupported) {
                    player.positionChanged()
                }
            }
        }
    }
}
