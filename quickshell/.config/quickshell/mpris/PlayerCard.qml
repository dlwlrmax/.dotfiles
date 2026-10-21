import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Qt5Compat.GraphicalEffects
import qs.common

// One media player: blurred cover backdrop, art, title/artist, seek bar and controls.
Rectangle {
    id: card

    property Theme theme: ThemeStore
    required property var player
    signal focusRequested()

    readonly property real trackLen: MediaInfo.trackLength(player)
    readonly property bool playing: player.playbackState === MprisPlaybackState.Playing
    readonly property bool hasArt: !!player.trackArtUrl

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 24
    radius: theme.radiusLg
    color: theme.mantle
    clip: true

    // Blurred, darkened cover as the card background.
    Image {
        id: bgArt
        anchors.fill: parent
        visible: false
        source: card.player.trackArtUrl || ""
        sourceSize: Qt.size(96, 96)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    FastBlur {
        anchors.fill: parent
        visible: card.hasArt && bgArt.status === Image.Ready
        source: bgArt
        radius: 48
        opacity: 0.5
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(card.theme.mantle, card.hasArt ? 0.62 : 0)
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // cover (click: raise the player's window)
            Rectangle {
                Layout.preferredWidth: 72
                Layout.preferredHeight: 72
                radius: card.theme.radiusMd
                color: card.theme.surface0
                clip: true

                Image {
                    anchors.fill: parent
                    visible: card.hasArt
                    source: card.player.trackArtUrl || ""
                    sourceSize: Qt.size(160, 160)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: !card.hasArt
                    text: "󰝚"
                    color: card.theme.subtext0
                    font.pixelSize: 30
                    font.family: card.theme.font
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.focusRequested()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                RowLayout {
                    spacing: 6

                    Badge {
                        theme: card.theme
                        text: card.player.identity || "Player"
                        clr: card.playing ? card.theme.green : card.theme.subtext0
                    }

                    Text {
                        text: card.playing ? "playing" : card.player.playbackState === MprisPlaybackState.Paused ? "paused" : "stopped"
                        color: card.theme.overlay0
                        font.pixelSize: card.theme.fontSizeMin
                        font.family: card.theme.fontUi
                    }
                }

                Text {
                    id: titleText
                    Layout.fillWidth: true
                    text: card.player.trackTitle || "Unknown title"
                    color: card.theme.text
                    font.pixelSize: card.theme.fontSize + 1
                    font.bold: true
                    font.family: card.theme.fontUi
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: [card.player.trackArtist, card.player.trackAlbum].filter(function (x) { return !!x }).join(" · ")
                    color: card.theme.subtext0
                    font.pixelSize: card.theme.fontSize - 1
                    font.family: card.theme.fontUi
                    elide: Text.ElideRight
                }
            }
        }

        // Seek bar when the player reports both position and length.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: card.player.positionSupported && card.trackLen > 1

            Text {
                text: card.player.isPlaying && !(card.player.position > 0.5) ? "--:--" : MediaInfo.formatTime(card.player.position)
                color: card.theme.subtext0
                font.pixelSize: card.theme.fontSizeMin
                font.family: card.theme.font
            }

            Item {
                id: seek
                Layout.fillWidth: true
                Layout.preferredHeight: 14

                readonly property real ratio: card.trackLen > 0 && card.player.position > 0
                                              ? Math.max(0, Math.min(1, card.player.position / card.trackLen)) : 0

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: card.theme.trackColor

                    Rectangle {
                        width: parent.width * seek.ratio
                        height: parent.height
                        radius: 2
                        color: card.theme.highlight
                    }
                }

                Rectangle {
                    visible: seekMa.containsMouse || seekMa.pressed
                    x: parent.width * seek.ratio - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10
                    height: 10
                    radius: 5
                    color: card.theme.highlight
                }

                MouseArea {
                    id: seekMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: card.player.canSeek
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    function seekTo(x) {
                        card.player.position = Math.max(0, Math.min(1, x / width)) * card.trackLen
                    }
                    onPressed: mouse => seekTo(mouse.x)
                    onPositionChanged: mouse => { if (pressed) seekTo(mouse.x) }
                }
            }

            Text {
                text: MediaInfo.formatTime(card.trackLen)
                color: card.theme.subtext0
                font.pixelSize: card.theme.fontSizeMin
                font.family: card.theme.font
            }
        }

        // Elapsed time with an indeterminate bar for players with no known length.
        RowLayout {
            id: liveRow
            Layout.fillWidth: true
            spacing: 8
            visible: card.player.isPlaying && card.player.positionSupported
                     && card.player.position > 0.5 && !(card.trackLen > 1)

            Text {
                text: MediaInfo.formatTime(card.player.position)
                color: card.theme.subtext0
                font.pixelSize: card.theme.fontSizeMin
                font.family: card.theme.font
            }

            Rectangle {
                id: liveTrack
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: card.theme.trackColor
                clip: true

                Rectangle {
                    id: liveFill
                    width: 40
                    height: 4
                    radius: 2
                    color: card.theme.green
                    NumberAnimation on x {
                        from: -liveFill.width
                        to: liveTrack.width
                        duration: 1200
                        loops: Animation.Infinite
                        running: liveRow.visible
                    }
                }
            }
        }

        // transport
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            IconButton {
                theme: card.theme
                text: "󰒝"        // shuffle
                glyphSize: card.theme.fontSize + 4
                implicitWidth: 30; implicitHeight: 30
                enabled: card.player.shuffleSupported
                tint: card.player.shuffle ? card.theme.highlight : card.theme.overlay1
                onClicked: card.player.shuffle = !card.player.shuffle
            }

            IconButton {
                theme: card.theme
                text: "󰒮"        // skip previous
                glyphSize: card.theme.fontSize + 8
                implicitWidth: 34; implicitHeight: 34
                enabled: card.player.canGoPrevious
                onClicked: card.player.previous()
            }

            IconButton {
                theme: card.theme
                text: card.playing ? "󰏤" : "󰐊"   // pause / play
                glyphSize: card.theme.fontSize + 10
                implicitWidth: 42; implicitHeight: 42
                radius: 21
                enabled: card.player.canTogglePlaying
                fill: card.theme.highlight
                onClicked: card.player.togglePlaying()
            }

            IconButton {
                theme: card.theme
                text: "󰒭"        // skip next
                glyphSize: card.theme.fontSize + 8
                implicitWidth: 34; implicitHeight: 34
                enabled: card.player.canGoNext
                onClicked: card.player.next()
            }

            IconButton {
                theme: card.theme
                // loopState: 0 none, 1 track, 2 playlist
                text: card.player.loopState === 1 ? "󰑘" : card.player.loopState === 2 ? "󰑖" : "󰑗"
                glyphSize: card.theme.fontSize + 4
                implicitWidth: 30; implicitHeight: 30
                enabled: card.player.loopSupported
                tint: card.player.loopState !== 0 ? card.theme.highlight : card.theme.overlay1
                onClicked: card.player.loopState = (card.player.loopState + 1) % 3
            }
        }

        // player volume
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: card.player.volumeSupported

            Text {
                text: "󰕾"
                color: card.theme.subtext0
                font.pixelSize: card.theme.fontSize + 2
                font.family: card.theme.font
            }

            Slider {
                id: vol
                Layout.fillWidth: true
                Layout.preferredHeight: 16
                from: 0
                to: 1
                value: card.player.volume
                onMoved: card.player.volume = value

                background: Rectangle {
                    x: vol.leftPadding
                    y: vol.topPadding + vol.availableHeight / 2 - height / 2
                    width: vol.availableWidth
                    height: 4
                    radius: 2
                    color: card.theme.trackColor

                    Rectangle {
                        width: vol.visualPosition * parent.width
                        height: parent.height
                        radius: parent.radius
                        color: card.theme.green
                    }
                }

                handle: Rectangle {
                    x: vol.leftPadding + vol.visualPosition * (vol.availableWidth - width)
                    y: vol.topPadding + vol.availableHeight / 2 - height / 2
                    width: 10
                    height: 10
                    radius: 5
                    color: card.theme.green
                }
            }

            Text {
                text: Math.round(card.player.volume * 100) + "%"
                color: card.theme.overlay0
                font.pixelSize: card.theme.fontSizeMin
                font.family: card.theme.font
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
