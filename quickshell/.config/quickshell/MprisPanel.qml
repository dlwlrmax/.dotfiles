import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: root
    property Theme theme: Theme {}
    property bool active: false
    signal close()

    clip: true
    implicitWidth: 360
    implicitHeight: playerList.implicitHeight + header.implicitHeight + 40

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
                text: "Media" + (Mpris.players.rowCount() > 0 ? " (" + Mpris.players.rowCount() + ")" : "")
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

        ColumnLayout {
            id: playerList
            Layout.fillWidth: true
            spacing: 12

            Repeater {
                model: Mpris.players

                delegate: ColumnLayout {
                    required property var modelData
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
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: modelData.identity || "Unknown Player"
                                color: theme.subtext1
                                font.pixelSize: theme.fontSize - 1
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: {
                                    var artist = modelData.trackArtist
                                    var title = modelData.trackTitle
                                    if (artist && title) return artist + " - " + title
                                    return title || "No track"
                                }
                                color: theme.text
                                font.pixelSize: theme.fontSize
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
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

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 2

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
                                width: modelData.length > 0 ? (modelData.position / modelData.length) * parent.width : 0
                            }
                        }

                        Text {
                            text: formatTime(modelData.length)
                            color: theme.subtext0
                            font.pixelSize: theme.fontSize - 2
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
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
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: modelData.length > 0 || modelData.volumeSupported
                        height: 1
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: Mpris.players.rowCount() === 0
                text: "No media players"
                color: theme.subtext0
                font.pixelSize: theme.fontSize
                font.family: theme.font
                Layout.topMargin: 20
                Layout.bottomMargin: 20
            }
        }
    }

    function formatTime(seconds) {
        if (!seconds || seconds <= 0) return "--:--"
        var totalSec = Math.floor(seconds)
        var min = Math.floor(totalSec / 60)
        var sec = totalSec % 60
        return min + ":" + (sec < 10 ? "0" : "") + sec
    }

    Timer {
        interval: 1000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            for (var i = 0; i < Mpris.players.rowCount(); i++) {
                var player = Mpris.players.rowAt(i)
                if (player && player.isPlaying) {
                    player.positionChanged()
                }
            }
        }
    }
}
