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
    property bool dnd: !!(dataSource && dataSource.dnd)
    property var reversedNotifs: dataSource && dataSource.activeNotifs
        ? dataSource.activeNotifs.slice().reverse() : []
    property var expandedGroups: ({})
    property var groupedNotifs: root.groupNotifications(root.reversedNotifs)
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
                text: "Notifications" + (root.reversedNotifs.length > 0
                    ? " (" + root.reversedNotifs.length + ")" : "")
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
                model: root.groupedNotifs

                delegate: Item {
                    required property var modelData
                    width: notifList.width
                    implicitHeight: sectionLayout.implicitHeight
                    height: implicitHeight

                    ColumnLayout {
                        id: sectionLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 42
                            radius: 8
                            color: root.theme.surface1
                            border.color: root.theme.surface0
                            border.width: 1

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 4
                                radius: 2
                                color: modelData.latest && modelData.latest.urgency === 2
                                    ? root.theme.red : root.theme.surface0
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 10
                                spacing: 8

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: root.theme.color
                                    AppIcon {
                                        anchors.centerIn: parent
                                        appId: modelData.latest && modelData.latest.desktopEntry || ""
                                        iconName: modelData.latest && modelData.latest.appIcon || ""
                                        size: 20
                                        hideOnMissing: true
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.appName || "Unknown"
                                    color: root.theme.text
                                    font.pixelSize: root.theme.fontSize
                                    font.bold: true
                                    font.family: root.theme.font
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    implicitWidth: countText.implicitWidth + 12
                                    implicitHeight: 22
                                    radius: 11
                                    color: root.theme.color
                                    Text {
                                        id: countText
                                        anchors.centerIn: parent
                                        text: modelData.messages.length
                                        color: root.theme.blue
                                        font.pixelSize: root.theme.fontSize - 2
                                        font.bold: true
                                    }
                                }

                                Text {
                                    text: modelData.expanded ? "▾" : "▸"
                                    color: root.theme.subtext0
                                    font.pixelSize: root.theme.fontSize
                                }

                                Text {
                                    text: "Clear"
                                    color: root.theme.blue
                                    font.pixelSize: root.theme.fontSize - 2
                                    font.family: root.theme.font
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -5
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.clearGroup(modelData.key)
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                z: -1
                                onClicked: root.toggleGroup(modelData.key)
                            }
                        }

                        ColumnLayout {
                            visible: modelData.expanded
                            Layout.fillWidth: true
                            spacing: 8
                            Repeater {
                                model: modelData.messages
                                delegate: NotificationCard {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    width: notifList.width
                                    theme: root.theme
                                    notifData: modelData
                                    notifTimes: root.notifTimes
                                }
                            }
                        }
                    }
                }
            }

            Text {
                id: emptyState
                anchors.centerIn: parent
                visible: notifList.count === 0
                text: "No notifications"
                color: theme.subtext0
                font.pixelSize: theme.fontSize
                font.family: theme.font
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: emptyState.bottom
                anchors.topMargin: 4
                visible: notifList.count === 0 && root.dnd
                text: "Do Not Disturb is on"
                color: theme.yellow
                font.pixelSize: theme.fontSize - 2
                font.family: theme.font
            }
        }
    }

    function notificationGroupKey(notif) {
        return notif.desktopEntry || notif.appName || notif.appIcon || "unknown"
    }

    function groupNotifications(notifs) {
        var groups = []
        for (var i = 0; i < notifs.length; ++i) {
            var notif = notifs[i]
            var key = root.notificationGroupKey(notif)
            var group = null
            for (var j = 0; j < groups.length; ++j) {
                if (groups[j].key === key) {
                    group = groups[j]
                    break
                }
            }
            if (!group) {
                group = {
                    key: key,
                    appName: notif.appName || "Unknown",
                    latest: notif,
                    messages: [],
                    expanded: root.expandedGroups[key] !== false
                }
                groups.push(group)
            }
            group.messages.push(notif)
        }
        return groups
    }

    function toggleGroup(key) {
        var next = {}
        for (var existing in root.expandedGroups) next[existing] = root.expandedGroups[existing]
        next[key] = root.expandedGroups[key] === false
        root.expandedGroups = next
    }

    function clearGroup(key) {
        var notifs = root.reversedNotifs
        for (var i = 0; i < notifs.length; ++i) {
            if (root.notificationGroupKey(notifs[i]) === key && notifs[i].dismiss)
                notifs[i].dismiss()
        }
    }
}
