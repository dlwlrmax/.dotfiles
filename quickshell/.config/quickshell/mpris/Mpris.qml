import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.common

Item {
    id: root
    property Theme theme: ThemeStore
    // First player playing a titled track (paused/idle players hide the widget).
    readonly property var currentPlayer: MediaInfo.playing
    property real maxWidth: 200
    signal togglePanel(int centerX)

    // Hard containment: layout squeeze must never paint over neighbors.
    clip: true
    visible: currentPlayer !== null && Prefs.show("mpris")
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    // Root bounds = visible area (clip: true). The label's own MouseArea can extend past
    // a squeezed widget over its neighbors; gate the tooltip on this.
    HoverHandler { id: rootHover }

    RowLayout {
        id: row
        // Track root width: fillWidth squeeze in bar would otherwise let the
        // row keep implicit size and paint over the Cpu widget.
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 6

        Text {
            text: root.currentPlayer ? (root.currentPlayer.isPlaying ? "" : "") : ""
            color: root.theme.mauve
            font.pixelSize: root.theme.fontSize + 5
            font.weight: Font.Medium
            font.family: theme.font
        }

        // (NN%) of track played; hidden unless both position and length known. Ticked by MediaInfo.
        Text {
            id: timeLabel
            readonly property var p: root.currentPlayer
            readonly property real len: MediaInfo.trackLength(p)
            readonly property bool shown: MediaInfo.hasPosition(p) && len > 1
            visible: shown
            text: shown ?"(" + Math.min(100, Math.floor(p.position / len * 100)) + "%)" : ""
            color: root.theme.subtext0
            font.pixelSize: root.theme.fontSize - 2
            font.weight: Font.Medium
            font.family: theme.font
            font.features: { "tnum": 1 }
            // Never squeezed; the title elides instead.
            Layout.minimumWidth: implicitWidth
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
            font.pixelSize: root.theme.fontSize - 2
            font.weight: Font.Medium
            font.family: theme.font
            elide: Text.ElideRight
            // maxWidth budgets time + title; title takes what's left (fillWidth lets
            // the layout shrink it, not the time, when the bar squeezes the widget).
            Layout.maximumWidth: Math.max(40, root.maxWidth
                - (timeLabel.visible ? timeLabel.implicitWidth + row.spacing : 0))
            Layout.preferredWidth: implicitWidth
            Layout.minimumWidth: 0
            Layout.fillWidth: true
        }
    }

    // Now-playing card: art, full title, artist/album, player, time.
    BarTooltip {
        id: labelTip
        readonly property var p: root.currentPlayer
        target: root
        theme: root.theme
        hovered: rootHover.hovered && !!p
        delay: 600

        RowLayout {
            spacing: 12

            Rectangle {
                visible: !!(labelTip.p && labelTip.p.trackArtUrl)
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                Layout.alignment: Qt.AlignTop
                radius: theme.radiusLg
                color: root.theme.surface0
                clip: true

                Image {
                    anchors.fill: parent
                    source: labelTip.p ? (labelTip.p.trackArtUrl || "") : ""
                    sourceSize: Qt.size(128, 128)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            ColumnLayout {
                spacing: 3
                Layout.maximumWidth: 300

                Text {
                    text: labelTip.p ? (labelTip.p.trackTitle || "Unknown") : ""
                    color: root.theme.text
                    font.pixelSize: root.theme.fontSize
                    font.weight: Font.Medium
                    font.family: root.theme.font
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    readonly property string line: labelTip.p
                        ? [labelTip.p.trackArtist, labelTip.p.trackAlbum].filter(x => !!x).join(" · ") : ""
                    visible: line !== ""
                    text: line
                    color: root.theme.subtext0
                    font.pixelSize: root.theme.fontSize - 1
                    font.family: root.theme.font
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    readonly property string progress: MediaInfo.formatProgress(labelTip.p, " / ")
                    text: (labelTip.p ? (labelTip.p.identity || "") : "")
                        + (progress !== "" ? "  ·  " + progress : "")
                    color: root.theme.overlay0
                    font.pixelSize: root.theme.fontSize - 2
                    font.family: root.theme.font
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 2
            implicitHeight: 1
            color: root.theme.surface0
        }

        Text {
            text: "Click %/title: panel · icon: play/pause · Right: next · Middle: prev · Scroll: volume"
            color: root.theme.overlay0
            font.pixelSize: root.theme.fontSize - 2
            font.family: root.theme.font
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // Left: panel (on time/title) / play-pause (on icon); right: next; middle: previous.
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            labelTip.suppressed = true
            if (!root.currentPlayer) return
            if (mouse.button === Qt.LeftButton) {
                var textStart = (timeLabel.visible ? timeLabel : trackLabel).mapToItem(root, 0, 0).x
                if (mouse.x >= textStart) {
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
        // Wheel: player volume (5% per notch) when it has one, else previous/next.
        onWheel: wheel => {
            var p = root.currentPlayer
            if (!p) return
            if (p.volumeSupported) {
                var v = Math.max(0, Math.min(1, p.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)))
                p.volume = v
            } else if (wheel.angleDelta.y > 0) {
                if (p.canGoNext) p.next()
            } else if (wheel.angleDelta.y < 0) {
                if (p.canGoPrevious) p.previous()
            }
        }
    }
}
