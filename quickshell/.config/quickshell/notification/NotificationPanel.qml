import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property bool active: false
    property var dataSource: null
    property var notifTimes: ({})
    property var reversedNotifs: dataSource ? dataSource.activeNotifs.slice().reverse() : []
    signal close()

    clip: true
    implicitWidth: 360
    implicitHeight: 480

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
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Notifications" + (notifList.count > 0 ? " (" + notifList.count + ")" : "")
                color: theme.text
                font.pixelSize: theme.fontSize + 1
                font.bold: true
                font.family: theme.font
                Layout.fillWidth: true
            }

            Text {
                text: "Clear All"
                color: theme.blue
                font.pixelSize: theme.fontSize - 1
                font.family: theme.font

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.dataSource && root.dataSource.clearAll)
                            root.dataSource.clearAll()
                    }
                }
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

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: notifList
                anchors.fill: parent
                spacing: 8
                clip: true
                model: reversedNotifs

                delegate: NotificationCard {
                    theme: root.theme
                    notifData: modelData
                    notifTimes: root.notifTimes
                    width: notifList.width
                }
            }

            Text {
                anchors.centerIn: parent
                visible: notifList.count === 0
                text: "No notifications"
                color: theme.subtext0
                font.pixelSize: theme.fontSize
                font.family: theme.font
            }
        }
    }
}
