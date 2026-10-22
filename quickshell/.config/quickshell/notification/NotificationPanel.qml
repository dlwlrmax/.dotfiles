import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import "../common/ListSync.js" as Sync

Item {
    id: root
    property Theme theme: ThemeStore
    property bool active: false
    property var dataSource: null
    property var notifTimes: ({})
    property bool dnd: !!(dataSource && dataSource.dnd)

    // Which tab is shown: "unread" (live + unread history) or "read".
    property string tab: "unread"

    // Live (currently active) notifications — shown first in the Unread tab.
    property var reversedNotifs: dataSource && dataSource.activeNotifs
        ? dataSource.activeNotifs.slice().reverse() : []
    property var groupedNotifs: root.groupNotifications(root.reversedNotifs)

    // DB row ids backing the live notifications, so history can skip them and
    // avoid showing the same notification twice (once live, once as history).
    // NOTE: plain binding (not IIFE) so it re-evaluates whenever activeNotifs
    // is reassigned (concat on add, slice on close/dismiss, reset on clearAll).
    property var liveIds: {
        var m = {}
        var a = dataSource && dataSource.activeNotifs ? dataSource.activeNotifs : []
        for (var i = 0; i < a.length; i++)
            if (a[i] && a[i]._dbId !== undefined && a[i]._dbId !== null)
                m[a[i]._dbId] = true
        return m
    }

    property var historyAll: dataSource && dataSource.history ? dataSource.history : []
    property var historyRows: root.historyAll.filter(function(r) {
        return !(r.id !== undefined && root.liveIds[r.id])
    })
    property var unreadRows: root.historyRows.filter(function(r) { return r.read !== 1 })
    property var readRows: root.historyRows.filter(function(r) { return r.read === 1 })

    property int unreadCount: root.reversedNotifs.length + root.unreadRows.length
    property int totalCount: root.unreadCount
    property var expandedGroups: ({})

    signal close()

    // Card lists are ListModels of keys, updated in place: a click or an incoming notification
    // only touches the cards that changed, so the others keep their expanded state.
    ListModel { id: groupModel }
    ListModel { id: unreadModel }
    ListModel { id: readModel }
    property var historyById: ({})
    property var groupByKey: ({})

    function syncLists() {
        var h = {}, g = {}, i
        for (i = 0; i < historyRows.length; i++) h[historyRows[i].id] = historyRows[i]
        for (i = 0; i < groupedNotifs.length; i++) g[groupedNotifs[i].key] = groupedNotifs[i]
        historyById = h          // maps first: delegates re-read their row from them
        groupByKey = g
        Sync.sync(groupModel, groupedNotifs.map(function (x) { return String(x.key) }))
        Sync.sync(unreadModel, unreadRows.map(function (r) { return String(r.id) }))
        Sync.sync(readModel, readRows.map(function (r) { return String(r.id) }))
    }

    onGroupedNotifsChanged: syncLists()
    onUnreadRowsChanged: syncLists()
    onReadRowsChanged: syncLists()
    Component.onCompleted: syncLists()

    clip: true
    implicitWidth: theme.panelWidthS
    // Content height (14px margins + header + 10 spacing + tab bar + 10 spacing + list),
    // capped at 640px (or the screen under the bar, if smaller); the list scrolls beyond that.
    readonly property real maxHeight: {
        var scr = root.QsWindow.window ? root.QsWindow.window.screen : null
        return Math.min(640, scr ? scr.height - theme.barHeight - 24 : 640)
    }
    implicitHeight: Math.min(maxHeight, 14 + panelHeader.implicitHeight + 10 + tabBar.implicitHeight + 10 + contentCol.implicitHeight + 14)

    PanelBackground {
        anchors.fill: parent
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        PanelHeader {
            id: panelHeader
            theme: root.theme
            title: "Notifications" + (root.totalCount > 0 ? " (" + root.totalCount + ")" : "")
            onClose: root.close()

            Badge {
                theme: root.theme
                text: "Clear all"
                clr: theme.blue
                clickable: true
                onClicked: {
                    if (root.dataSource && root.dataSource.clearAll)
                        root.dataSource.clearAll()
                }
            }
        }

        RowLayout {
            id: tabBar
            Layout.fillWidth: true
            spacing: 6

            Badge {
                Layout.fillWidth: true
                implicitHeight: 26
                theme: root.theme
                text: "Unread" + (root.unreadCount > 0 ? " (" + root.unreadCount + ")" : "")
                pixelSize: theme.fontSize - 1
                clr: theme.blue
                solid: root.tab === "unread"
                clickable: true
                onClicked: root.tab = "unread"
            }

            Badge {
                Layout.fillWidth: true
                implicitHeight: 26
                theme: root.theme
                text: "Read" + (root.readRows.length > 0 ? " (" + root.readRows.length + ")" : "")
                pixelSize: theme.fontSize - 1
                clr: theme.blue
                solid: root.tab === "read"
                clickable: true
                onClicked: root.tab = "read"
            }
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

                    // ── Unread (live notifications on top, then unread history) ──
                    ColumnLayout {
                        visible: root.tab === "unread"
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "Mark all read"
                                color: theme.blue
                                font.pixelSize: theme.fontSize - 1
                                font.family: theme.font
                                visible: root.unreadCount > 0

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var live = root.reversedNotifs
                                        for (var i = 0; i < live.length; ++i)
                                            if (live[i].dismiss) live[i].dismiss()
                                        if (root.dataSource && root.dataSource.markAllRead)
                                            root.dataSource.markAllRead()
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.unreadCount === 0
                            text: root.dnd ? "Do Not Disturb is on" : "Nothing unread"
                            color: theme.subtext0
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                        }

                        // Live notifications — grouped by app, with dismiss,
                        // action buttons, and urgency styling.
                        Repeater {
                            model: groupModel
                            delegate: activeGroupDelegate
                        }

                        // Unread history rows below the live ones.
                        Repeater {
                            model: unreadModel
                            delegate: historyCardDelegate
                        }
                    }

                    // ── Read ───────────────────────────────────
                    ColumnLayout {
                        visible: root.tab === "read"
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Item { Layout.fillWidth: true }

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
                            model: readModel
                            delegate: historyCardDelegate
                        }
                    }
                }
            }
        }
    }

    // ── delegates ──────────────────────────────────────────────

    Component {
        id: historyCardDelegate
        NotificationCard {
            required property string k
            readonly property var modelData: root.historyById[k] || ({})
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
            required property string k
            readonly property var modelData: root.groupByKey[k] || ({ messages: [], key: k })
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
                    implicitHeight: modelData.expanded ? 42 : 52
                    radius: theme.radiusLg
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
                            color: root.theme.panelColor
                            AppIcon {
                                anchors.centerIn: parent
                                appId: modelData.latest && modelData.latest.desktopEntry || ""
                                iconName: modelData.latest && modelData.latest.appIcon || ""
                                size: 20
                                hideOnMissing: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: modelData.appName || "Unknown"
                                color: root.theme.text
                                font.pixelSize: root.theme.fontSize
                                font.bold: true
                                font.family: root.theme.fontUi
                                elide: Text.ElideRight
                            }

                            // One-line preview of the latest message while collapsed.
                            Text {
                                Layout.fillWidth: true
                                visible: !modelData.expanded && text !== ""
                                text: {
                                    var n = modelData.latest
                                    if (!n) return ""
                                    var t = n.summary || ""
                                    var b = (n.body || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim()
                                    return t && b ? t + " — " + b : (t || b)
                                }
                                color: root.theme.subtext0
                                font.pixelSize: root.theme.fontSizeMin
                                font.family: root.theme.fontUi
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            implicitWidth: countText.implicitWidth + 12
                            implicitHeight: 22
                            radius: 11
                            color: root.theme.panelColor
                            Text {
                                font.family: theme.font
                                id: countText
                                anchors.centerIn: parent
                                text: modelData.messages.length
                                color: root.theme.blue
                                font.pixelSize: root.theme.fontSizeMin
                                font.bold: true
                            }
                        }

                        Text {
                            font.family: theme.font
                            text: modelData.expanded ? Glyphs.down : Glyphs.next
                            color: root.theme.subtext0
                            font.pixelSize: root.theme.fontSize
                        }

                        Text {
                            text: "Clear"
                            color: root.theme.blue
                            font.pixelSize: root.theme.fontSizeMin
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
                            unread: true
                            // Live entries stay under Unread while active, so both
                            // read-click and × retire them (see retireLive).
                            onDismissRequest: function() { root.retireLive(modelData) }
                            onMarkRead: function() { root.retireLive(modelData) }
                        }
                    }
                }
            }
        }
    }

    // ── helpers ────────────────────────────────────────────────

    function notificationGroupKey(notif) {
        // Normalize: desktopEntry is the stable id; bare appName varies in
        // case/whitespace per sender ("Telegram" vs "telegram") and would
        // split one app into several groups. appIcon is per-notification
        // artwork, never a grouping key — last-resort fallback only.
        var de = (notif.desktopEntry || "").trim().toLowerCase()
        if (de) return de
        var app = (notif.appName || "").trim().toLowerCase()
        if (app) return app
        return (notif.appIcon || "unknown")
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

    // Clear = done: mark the backing row read so it drops into Read once its
    // live entry is gone, instead of resurfacing as Unread.
    function retireLive(notif) {
        if (!notif) return
        var dbId = notif._dbId
        if (dbId !== undefined && dbId !== null && root.dataSource)
            root.dataSource.markRead(dbId)
        if (notif.dismiss) notif.dismiss()
    }

    function clearGroup(key) {
        var notifs = root.reversedNotifs
        for (var i = 0; i < notifs.length; ++i)
            if (root.notificationGroupKey(notifs[i]) === key) root.retireLive(notifs[i])
    }
}
