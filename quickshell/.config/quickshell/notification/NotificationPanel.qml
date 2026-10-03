import QtQuick
import QtQuick.Controls
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

    // Live (currently active) notifications — kept as their own section.
    property var reversedNotifs: dataSource && dataSource.activeNotifs
        ? dataSource.activeNotifs.slice().reverse() : []
    property var groupedNotifs: root.groupNotifications(root.reversedNotifs)

    // DB row ids backing the live notifications, so history can skip them and
    // avoid showing the same notification twice (once live, once as history).
    property var liveIds: (function() {
        var m = {}
        var a = dataSource && dataSource.activeNotifs ? dataSource.activeNotifs : []
        for (var i = 0; i < a.length; i++)
            if (a[i] && a[i]._dbId !== undefined && a[i]._dbId !== null)
                m[a[i]._dbId] = true
        return m
    })()

    property var historyAll: dataSource && dataSource.history ? dataSource.history : []
    property var historyRows: root.historyAll.filter(function(r) {
        return !(r.id !== undefined && root.liveIds[r.id])
    })
    property var unreadRows: root.historyRows.filter(function(r) { return r.read !== 1 })
    property var readRows: root.historyRows.filter(function(r) { return r.read === 1 })

    property int totalCount: root.reversedNotifs.length + root.unreadRows.length
    property var expandedGroups: ({})

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
                text: "Notifications" + (root.totalCount > 0
                    ? " (" + root.totalCount + ")" : "")
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

            Flickable {
                id: scroll
                anchors.fill: parent
                contentHeight: contentCol.implicitHeight
                clip: true
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                ColumnLayout {
                    id: contentCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 12

                    // ── Active (live) ───────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: root.reversedNotifs.length > 0

                        Text {
                            text: "Active"
                            color: theme.subtext0
                            font.pixelSize: theme.fontSize - 1
                            font.bold: true
                            font.family: theme.font
                        }

                        Repeater {
                            model: root.groupedNotifs
                            delegate: activeGroupDelegate
                        }
                    }

                    // ── Unread ─────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Unread" + (root.unreadRows.length > 0
                                    ? " (" + root.unreadRows.length + ")" : "")
                                color: theme.text
                                font.pixelSize: theme.fontSize
                                font.bold: true
                                font.family: theme.font
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "Mark all read"
                                color: theme.blue
                                font.pixelSize: theme.fontSize - 1
                                font.family: theme.font
                                visible: root.unreadRows.length > 0

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.dataSource && root.dataSource.markAllRead)
                                            root.dataSource.markAllRead()
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.unreadRows.length === 0
                            text: "Nothing unread"
                            color: theme.subtext0
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                        }

                        Repeater {
                            model: root.unreadRows
                            delegate: historyCardDelegate
                        }
                    }

                    // ── Read ───────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Read" + (root.readRows.length > 0
                                    ? " (" + root.readRows.length + ")" : "")
                                color: theme.text
                                font.pixelSize: theme.fontSize
                                font.bold: true
                                font.family: theme.font
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "Clear read"
                                color: theme.blue
                                font.pixelSize: theme.fontSize - 1
                                font.family: theme.font
                                visible: root.readRows.length > 0

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.dataSource && root.dataSource.clearRead)
                                            root.dataSource.clearRead()
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.readRows.length === 0
                            text: "No read notifications"
                            color: theme.subtext0
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                        }

                        Repeater {
                            model: root.readRows
                            delegate: historyCardDelegate
                        }
                    }

                    Text {
                        visible: root.reversedNotifs.length === 0
                            && root.unreadRows.length === 0
                            && root.readRows.length === 0
                            && !root.dnd
                        text: "No notifications"
                        color: theme.subtext0
                        font.pixelSize: theme.fontSize
                        font.family: theme.font
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        visible: root.reversedNotifs.length === 0
                            && root.unreadRows.length === 0
                            && root.readRows.length === 0
                            && root.dnd
                        text: "Do Not Disturb is on"
                        color: theme.yellow
                        font.pixelSize: theme.fontSize - 2
                        font.family: theme.font
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }

    // ── delegates ──────────────────────────────────────────────

    Component {
        id: historyCardDelegate
        NotificationCard {
            required property var modelData
            Layout.fillWidth: true
            width: contentCol.width
            theme: root.theme
            notifData: modelData
            notifTimes: ({})
            read: modelData.read === 1
            unread: modelData.read !== 1
            // Callbacks must be function literals: a bare binding here would
            // invoke deleteHistoryRow/markRead the moment the delegate is
            // created, wiping every row without a click.
            onDismissRequest: function() {
                if (root.dataSource) root.dataSource.deleteHistoryRow(modelData.id)
            }
            onMarkRead: function() {
                if (root.dataSource) root.dataSource.markRead(modelData.id)
            }
        }
    }

    Component {
        id: activeGroupDelegate
        Item {
            required property var modelData
            width: contentCol.width
            implicitHeight: agCol.implicitHeight
            height: implicitHeight

            ColumnLayout {
                id: agCol
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
                            width: contentCol.width
                            theme: root.theme
                            notifData: modelData
                            notifTimes: root.notifTimes
                            onMarkRead: function() {
                                if (root.dataSource) root.dataSource.markRead(modelData._dbId)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── helpers ────────────────────────────────────────────────

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
            if (root.notificationGroupKey(notifs[i]) === key && notifs[i].dismiss) {
                // Clear = done: mark the backing row read so it drops into Read
                // once its live entry is gone, instead of resurfacing as Unread.
                var dbId = notifs[i]._dbId
                if (dbId !== undefined && dbId !== null && root.dataSource)
                    root.dataSource.markRead(dbId)
                notifs[i].dismiss()
            }
        }
    }
}
