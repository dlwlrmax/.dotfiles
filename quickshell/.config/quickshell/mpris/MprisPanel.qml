import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
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
        root.playerModel = out
    }
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
    implicitWidth: 360
    implicitHeight: (root.playerModel.length > 0 ? Math.min(playerList.implicitHeight, root.maxListHeight) : 60) + header.implicitHeight + 40

    Rectangle {
        anchors.fill: parent
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 16
        bottomRightRadius: 16
        color: theme.color
        border.color: theme.surface0
        border.width: 2

        // mask top border
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: theme.color
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            id: header
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Media" + (root.playerModel.length > 0 ? " (" + root.playerModel.length + ")" : "")
                color: theme.text
                font.pixelSize: theme.fontSize + 1
                font.bold: true
                font.family: theme.font
                Layout.fillWidth: true
            }

            Text {
                text: "×"
                color: theme.subtext0
                font.pixelSize: theme.fontSize + 4

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.surface0
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
                spacing: 12

                Repeater {
                    model: root.playerModel

                    delegate: ColumnLayout {
                        required property var modelData
                        required property int index
                        spacing: 8
                        Layout.fillWidth: true

                        Rectangle {
                            Layout.fillWidth: true
                            color: theme.surface0
                            height: 1
                            visible: index > 0
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                width: 48
                                height: 48
                                radius: 6
                                color: theme.surface0

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: modelData.trackArtUrl || ""
                                    sourceSize.width: 44
                                    sourceSize.height: 44
                                    fillMode: Image.PreserveAspectFit
                                    visible: modelData.trackArtUrl !== ""
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "♪"
                                    color: theme.subtext0
                                    font.pixelSize: 20
                                    visible: !(modelData.trackArtUrl !== "")
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (typeof modelData.raise === "function" && modelData.canRaise) {
                                            modelData.raise()
                                        } else {
                                            root.focusPlayer(modelData)
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: {
                                            if (modelData.playbackState === MprisPlaybackState.Playing) return "●"
                                            if (modelData.playbackState === MprisPlaybackState.Paused) return "❚❚"
                                            return ""
                                        }
                                        color: modelData.playbackState === MprisPlaybackState.Playing ? theme.green : theme.subtext0
                                        font.pixelSize: theme.fontSize - 3
                                    }

                                    Text {
                                        text: modelData.identity || "Unknown Player"
                                        color: theme.subtext1
                                        font.pixelSize: theme.fontSize - 1
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                Text {
                                    id: trackTitleText
                                    text: {
                                        var artist = modelData.trackArtist
                                        var title = modelData.trackTitle
                                        if (artist && title) return artist + " - " + title
                                        return title || "Unknown Title"
                                    }
                                    color: theme.text
                                    font.pixelSize: theme.fontSize
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true

                                    MouseArea {
                                        id: titleHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    ToolTip.visible: titleHover.containsMouse && trackTitleText.truncated
                                    ToolTip.delay: 500
                                    ToolTip.text: trackTitleText.text
                                }

                                Text {
                                    text: modelData.trackAlbum || ""
                                    color: theme.subtext0
                                    font.pixelSize: theme.fontSize - 1
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    visible: modelData.trackAlbum !== ""
                                }
                            }
                        }

                        // Playtime row: only meaningful when the player exposes
                        // BOTH a live position and a real length. Zen/Firefox
                        // report a frozen Position 0 with no mpris:length, so the
                        // whole row stays hidden there instead of showing "--:--".
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: modelData.positionSupported && modelData.lengthSupported && modelData.length > 1

                            Text {
                                text: formatTime(modelData.position)
                                color: theme.subtext0
                                font.pixelSize: theme.fontSize - 2
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 4
                                radius: 2
                                color: theme.surface0

                                Rectangle {
                                    height: 4
                                    radius: 2
                                    color: theme.mauve
                                    width: {
                                        if (!modelData.positionSupported || !modelData.lengthSupported) return 0
                                        if (!(modelData.length > 0)) return 0
                                        if (!(modelData.position > 0)) return 0
                                        var r = modelData.position / modelData.length
                                        if (r < 0) r = 0
                                        if (r > 1) r = 1
                                        return r * parent.width
                                    }
                                }
                            }

                            Text {
                                text: formatTime(modelData.length)
                                color: theme.subtext0
                                font.pixelSize: theme.fontSize - 2
                            }
                        }

                        // Fallback row for players (Zen/Firefox) that expose a
                        // live position but no mpris:length, so the full time
                        // row above stays hidden. Indeterminate bar + elapsed
                        // time + LIVE tag; never renders "--:--".
                        RowLayout {
                            id: liveRow
                            Layout.fillWidth: true
                            spacing: 6
                            visible: modelData.isPlaying && modelData.positionSupported
                                && modelData.position > 0.5
                                && !(modelData.lengthSupported && modelData.length > 1)

                            Text {
                                text: formatTime(modelData.position)
                                color: theme.subtext0
                                font.pixelSize: theme.fontSize - 2
                            }

                            Rectangle {
                                id: liveTrack
                                Layout.fillWidth: true
                                height: 4
                                radius: 2
                                color: theme.surface0
                                clip: true

                                Rectangle {
                                    id: liveFill
                                    width: 40
                                    height: 4
                                    radius: 2
                                    color: theme.green
                                    x: -width

                                    NumberAnimation on x {
                                        from: -liveFill.width
                                        to: liveTrack.width
                                        duration: 1200
                                        loops: Animation.Infinite
                                        running: liveRow.visible
                                    }
                                }
                            }

                            Text {
                                text: "LIVE"
                                color: theme.subtext0
                                font.pixelSize: theme.fontSize - 3
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillWidth: true
                            spacing: 16

                            Text {
                                text: "󰒮"
                                color: modelData.shuffle ? theme.mauve : theme.surface1
                                font.pixelSize: theme.fontSize + 2

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.shuffleSupported) modelData.shuffle = !modelData.shuffle
                                    }
                                }
                            }

                            Text {
                                text: "󰒭"
                                color: theme.subtext0
                                font.pixelSize: theme.fontSize + 5

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.canGoPrevious) modelData.previous()
                                    }
                                }
                            }

                            Text {
                                text: modelData.isPlaying ? "" : ""
                                color: theme.text
                                font.pixelSize: theme.fontSize + 6

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.canTogglePlaying) modelData.togglePlaying()
                                    }
                                }
                            }

                            Text {
                                text: "󰒧"
                                color: theme.subtext0
                                font.pixelSize: theme.fontSize + 5

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.canGoNext) modelData.next()
                                    }
                                }
                            }

                            Text {
                                text: {
                                    if (modelData.loopState === 0) return "󰓦"
                                    if (modelData.loopState === 1) return "󰓩"
                                    return "󰓧"
                                }
                                color: modelData.loopState !== 0 ? theme.mauve : theme.surface1
                                font.pixelSize: theme.fontSize + 2

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.loopSupported) {
                                            modelData.loopState = (modelData.loopState + 1) % 3
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "󰕾"
                                color: theme.subtext0
                                font.pixelSize: theme.fontSize
                                visible: modelData.volumeSupported
                                Layout.preferredWidth: 18
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Slider {
                                id: volumeSlider
                                Layout.fillWidth: true
                                Layout.preferredHeight: 16
                                visible: modelData.volumeSupported
                                from: 0
                                to: 1
                                value: modelData.volume
                                onMoved: modelData.volume = value

                                background: Rectangle {
                                    x: volumeSlider.leftPadding
                                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                    width: volumeSlider.availableWidth
                                    height: 4
                                    radius: 2
                                    color: theme.surface0

                                    Rectangle {
                                        width: volumeSlider.visualPosition * parent.width
                                        height: parent.height
                                        radius: parent.radius
                                        color: theme.green
                                    }
                                }

                                handle: Rectangle {
                                    x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: theme.green
                                }
                            }
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
                font.family: theme.font
            }

            Button {
                Layout.alignment: Qt.AlignHCenter
                text: "Open browser"
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

    // m:ss formatter. Guards NaN/negative (unsupported position) so the row,
    // which is only visible with real support, never shows a bogus value.
    function formatTime(seconds) {
        if (seconds === undefined || seconds === null || isNaN(seconds) || seconds < 0) return "--:--"
        var totalSec = Math.floor(seconds)
        var min = Math.floor(totalSec / 60)
        var sec = totalSec % 60
        return min + ":" + (sec < 10 ? "0" : "") + sec
    }

    // Poll live positions only when the panel is open AND at least one player
    // exposes a usable time source: a real length, or (fallback) a live
    // position while playing (Zen/Firefox send position but no mpris:length).
    Timer {
        interval: 1000
        running: root.active && root.playerModel.some(function(p) {
            return p && ((p.lengthSupported && p.length > 1)
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
