import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property bool active: false
    signal close()

    clip: true
    implicitWidth: 300
    implicitHeight: contentCol.implicitHeight + 28

    Rectangle {
        anchors.fill: parent
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 16
        bottomRightRadius: 16
        color: theme.color
        border.color: theme.surface0
        border.width: 2

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: theme.color
        }
    }

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "System tray"
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
                font.family: theme.font

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

        Flow {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: SystemTray.items
                delegate: TrayIcon {
                    boxSize: 28
                    onActivated: root.close()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: SystemTray.items.values.length === 0
            text: "No tray icons"
            color: theme.subtext0
            font.pixelSize: theme.fontSize
            font.family: theme.font
        }
    }
}
