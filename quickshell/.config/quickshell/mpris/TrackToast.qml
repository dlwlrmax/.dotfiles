import QtQuick
import QtQuick.Layouts
import qs.common

// Brief "now playing" card when a different track starts (MediaInfo.trackStarted).
// Fades in, holds, fades out; hover keeps it up, click dismisses.
Item {
    id: root
    property Theme theme: Theme {}
    property bool quiet: false            // gaming quiet mode for this screen
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

    function show(p) {
        if (quiet || !p) return
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
        id: holdTimer
        interval: root.holdMs
        onTriggered: if (cardHover.hovered) restart(); else root.opacity = 0
    }

    Rectangle {
        id: card
        implicitWidth: row.implicitWidth + 24
        implicitHeight: row.implicitHeight + 20
        radius: 12
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
                radius: 8
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
                    font.pixelSize: root.theme.fontSize - 2
                    font.family: root.theme.font
                }
                Text {
                    text: root.title
                    color: root.theme.text
                    font.pixelSize: root.theme.fontSize
                    font.weight: Font.Medium
                    font.family: root.theme.font
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    visible: root.subtitle !== ""
                    text: root.subtitle
                    color: root.theme.subtext0
                    font.pixelSize: root.theme.fontSize - 1
                    font.family: root.theme.font
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }
}
