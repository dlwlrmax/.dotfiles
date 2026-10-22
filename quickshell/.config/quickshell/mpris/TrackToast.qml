import QtQuick
import QtQuick.Layouts
import qs.common

// Brief "now playing" card when a different track starts (MediaInfo.trackStarted).
// Fades in, holds, fades out; hover keeps it up, click dismisses.
Item {
    id: root
    property Theme theme: ThemeStore
    property bool quiet: false            // gaming quiet mode for this screen
    property bool audible: true           // false when output is muted or at 0%
    property int holdMs: 3500

    // Snapshot at trigger time so a later metadata change doesn't rewrite the card.
    property string title: ""
    property string subtitle: ""
    property string art: ""
    property string player: ""

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight
    opacity: 0
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // Browser audio streams appear a moment after the MPRIS title changes.
    property var pending: null

    function show(p) {
        if (quiet || !audible || !p) return
        if (MediaInfo.isBrowser(p) && !MediaInfo.hasAudioStream(p)) {
            pending = p
            streamTimer.restart()
            return
        }
        title = p.trackTitle || ""
        subtitle = [p.trackArtist, p.trackAlbum].filter(x => !!x).join(" · ")
        art = p.trackArtUrl || ""
        player = p.identity || ""
        opacity = 1
        holdTimer.restart()
    }

    Connections {
        target: MediaInfo
        function onTrackStarted(p) { root.show(p) }
    }

    Timer {
        id: streamTimer
        interval: 800
        onTriggered: {
            var p = root.pending
            root.pending = null
            if (p && MediaInfo.playing === p && MediaInfo.hasAudioStream(p)) root.show(p)
        }
    }

    Timer {
        id: holdTimer
        interval: root.holdMs
        onTriggered: if (cardHover.hovered) restart(); else root.opacity = 0
    }

    Rectangle {
        id: card
        implicitWidth: row.implicitWidth + 24
        implicitHeight: row.implicitHeight + 20
        radius: theme.radiusXl
        color: root.theme.base
        border.color: root.theme.surface0
        border.width: 1

        HoverHandler { id: cardHover }
        TapHandler { onTapped: root.opacity = 0 }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                radius: theme.radiusLg
                color: root.theme.surface0
                clip: true

                Image {
                    anchors.fill: parent
                    visible: root.art !== ""
                    source: root.art
                    sourceSize: Qt.size(104, 104)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: root.art === ""
                    text: ""   // nf-fa-music
                    color: root.theme.mauve
                    font.pixelSize: root.theme.fontSize + 8
                    font.family: root.theme.font
                }
            }

            ColumnLayout {
                spacing: 2
                Layout.maximumWidth: 300

                Text {
                    text: "  " + (root.player || "Now playing")   // nf-fa-play
                    color: root.theme.mauve
                    font.pixelSize: root.theme.fontSizeMin
                    font.family: root.theme.font
                }
                Text {
                    text: root.title
                    color: root.theme.text
                    font.pixelSize: root.theme.fontSize
                    font.weight: Font.Medium
                    font.family: root.theme.fontUi
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    visible: root.subtitle !== ""
                    text: root.subtitle
                    color: root.theme.subtext0
                    font.pixelSize: root.theme.fontSize - 1
                    font.family: root.theme.fontUi
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }
}
