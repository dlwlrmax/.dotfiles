import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property var currentPlayer: null
    property real maxWidth: 200
    signal togglePanel(int centerX)

    visible: currentPlayer !== null
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    RowLayout {
        id: row
        spacing: 6

        Text {
            text: root.currentPlayer ? (root.currentPlayer.isPlaying ? "" : "") : ""
            color: root.theme.mauve
            font.pixelSize: root.theme.fontSize + 5
            font.weight: Font.Medium
            font.family: theme.font
        }

        Text {
            id: trackLabel
            text: {
                if (!root.currentPlayer) return ""
                var artist = root.currentPlayer.trackArtist
                var title = root.currentPlayer.trackTitle
                if (artist && title) return artist + " - " + title
                return title || "Unknown"
            }
            color: root.theme.text
            font.pixelSize: root.theme.fontSize - 1
            font.weight: Font.Medium
            font.family: theme.font
            elide: Text.ElideRight
            Layout.maximumWidth: root.maxWidth
            Layout.fillWidth: false
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (!root.currentPlayer) return
            if (mouse.button === Qt.LeftButton) {
                var labelPos = trackLabel.mapFromItem(root, mouse.x, mouse.y)
                if (labelPos.x >= 0 && labelPos.x <= trackLabel.width) {
                    var globalPos = root.mapToItem(null, 0, 0)
                    root.togglePanel(globalPos.x + root.width / 2)
                } else if (root.currentPlayer.canTogglePlaying) {
                    root.currentPlayer.togglePlaying()
                }
            } else if (mouse.button === Qt.RightButton) {
                if (root.currentPlayer.canGoNext) root.currentPlayer.next()
            } else if (mouse.button === Qt.MiddleButton) {
                if (root.currentPlayer.canGoPrevious) root.currentPlayer.previous()
            }
        }
        onWheel: wheel => {
            if (!root.currentPlayer) return
            if (wheel.angleDelta.y > 0) {
                if (root.currentPlayer.canGoNext) root.currentPlayer.next()
            } else if (wheel.angleDelta.y < 0) {
                if (root.currentPlayer.canGoPrevious) root.currentPlayer.previous()
            }
        }
    }

    function _refreshPlayer() {
        // prefer actively playing player
        for (var i = 0; i < Mpris.players.rowCount(); i++) {
            var p = Mpris.players.values[i]
            if (p && p.isPlaying) {
                root.currentPlayer = p
                return
            }
        }
        // fallback: show any player with a valid title
        // (skips stopped players with empty metadata, like our bridge)
        for (var i = 0; i < Mpris.players.rowCount(); i++) {
            var p = Mpris.players.values[i]
            if (p && p.trackTitle) {
                root.currentPlayer = p
                return
            }
        }
        root.currentPlayer = null
    }

    Repeater {
        model: Mpris.players
        delegate: Item {
            required property var modelData

            Connections {
                target: modelData
                function onIsPlayingChanged() { root._refreshPlayer() }
                function onPlaybackStateChanged() { root._refreshPlayer() }
            }

            Component.onCompleted: { root._refreshPlayer() }
            Component.onDestruction: { root._refreshPlayer() }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: root._refreshPlayer()
    }
}
