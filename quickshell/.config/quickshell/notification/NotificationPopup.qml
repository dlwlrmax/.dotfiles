import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.notification
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property var notifTimes: ({})
    property bool dnd: false
    property int maxWidth: 400
    property int maxVisible: 2
    // Backing data source (notifData Item in shell.qml). Used to broadcast
    // dismiss requests across screens so closing one popup closes all.
    property var dataSource: null

    implicitWidth: maxWidth
    implicitHeight: popupColumn.implicitHeight
    width: maxWidth

    clip: false

    // Track live cards by app key so cross-screen dismiss still reaches group.
    property var cards: ({})

    // Model stores only detached plain data. Live Quickshell Notification
    // QObjects must never be parked in ListModel roles: converting them back
    // through fromQVariantMap after the QObject is destroyed crashes the
    // QV4 engine (SIGSEGV inside QV4::fromQVariantMap).
    ListModel {
        id: notificationModel
    }

    // Snapshot the scalar fields we render. Everything is a plain JS value so
    // the snapshot stays valid after the source Notification is destroyed.
    function snapshotNotif(notif) {
        return {
            id: notif.id,
            appName: notif.appName || "",
            summary: notif.summary || "",
            body: notif.body || "",
            urgency: (notif.urgency !== undefined && notif.urgency !== null) ? notif.urgency : 1,
            timestamp: notif.timestamp || (Date.now() / 1000),
            appIcon: notif.appIcon || "",
            desktopEntry: notif.desktopEntry || "",
            expireTimeout: notif.expireTimeout || 0
        }
    }

    // Always emit the same role shape: object keys fixed, messages always an
    // array of plain objects. Prevents "role of different type [List ->
    // VariantMap]" and keeps Repeater delegate bindings stable.
    function makeGroup(key, messages) {
        return {
            key: key,
            appName: (messages.length && messages[0].appName) ? messages[0].appName : "Unknown",
            count: messages.length,
            messages: messages,
            latest: messages.length ? messages[0] : null
        }
    }

    ColumnLayout {
        id: popupColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        Repeater {
            model: notificationModel

            delegate: NotificationPopupCard {
                required property var group
                required property int index

                Layout.fillWidth: true
                Layout.minimumWidth: root.maxWidth
                Layout.preferredWidth: root.maxWidth
                Layout.maximumWidth: root.maxWidth
                width: root.maxWidth
                visible: index < root.maxVisible
                groupData: group
                notifTimes: root.notifTimes
                theme: root.theme

                // Keep layout shifts uniform when cards enter or leave stack.
                Behavior on y {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                Component.onCompleted: root.cards[group.key] = this
                Component.onDestruction: {
                    if (root.cards[group.key] === this)
                        delete root.cards[group.key]
                }

                // Delegate lifetime is driven solely by model removal. The card
                // fades, then asks for its row to go; Qt.callLater keeps the
                // model write out of the animation/signal emission stack.
                onDismissed: Qt.callLater(function() { root.removeGroup(group.key) })
                onDismissRequested: {
                    root.dismissGroup(group.key)
                }
                onMessageDismissRequested: function(notifId) {
                    root.removeMessage(group.key, notifId)
                    if (root.dataSource && root.dataSource.requestDismissPopup)
                        root.dataSource.requestDismissPopup(notifId)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.minimumWidth: root.maxWidth
            Layout.preferredWidth: root.maxWidth
            Layout.maximumWidth: root.maxWidth
            visible: notificationModel.count > root.maxVisible
            implicitHeight: 28
            radius: 14
            color: root.theme.surface1
            border.color: root.theme.surface0
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "+" + (notificationModel.count - root.maxVisible) + " more"
                color: root.theme.subtext0
                font.family: root.theme.font
                font.pixelSize: root.theme.fontSize - 2
            }

            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }
    }

    // React to broadcast dismiss from any screen.
    Connections {
        target: root.dataSource
        enabled: root.dataSource !== null
        function onDismissPopup(notifId) {
            var card = root.cardForNotification(notifId)
            if (card) card.fadeOut()
        }
    }

    function appKey(notif) {
        return notif.desktopEntry || notif.appName || notif.appIcon || "unknown"
    }

    function cardForNotification(notifId) {
        for (var i = 0; i < notificationModel.count; ++i) {
            var row = notificationModel.get(i)
            var group = row ? row.group : null
            if (!group || !group.messages) continue
            for (var j = 0; j < group.messages.length; ++j) {
                var message = group.messages[j]
                if (message && message.id === notifId)
                    return root.cards[group.key] || null
            }
        }
        return null
    }

    function onNotification(notif) {
        if (root.dnd || !notif) return
        if (!notif.tracked) return

        var key = root.appKey(notif)
        var snapshot = root.snapshotNotif(notif)
        for (var i = 0; i < notificationModel.count; ++i) {
            var row = notificationModel.get(i)
            var existing = row ? row.group : null
            if (!existing || existing.key !== key) continue

            var messages = (existing.messages || []).slice()
            messages.unshift(snapshot)
            notificationModel.setProperty(i, "group", root.makeGroup(key, messages))
            notificationModel.move(i, 0, 1)
            return
        }

        notificationModel.insert(0, {
            group: root.makeGroup(key, [snapshot])
        })
    }

    function dismissGroup(key) {
        var group = groupForKey(key)
        if (!group || !group.messages) return
        for (var i = 0; i < group.messages.length; ++i) {
            var message = group.messages[i]
            if (message && root.dataSource && root.dataSource.requestDismissPopup)
                root.dataSource.requestDismissPopup(message.id)
        }
    }

    function groupForKey(key) {
        for (var i = 0; i < notificationModel.count; ++i) {
            var row = notificationModel.get(i)
            if (row && row.group && row.group.key === key)
                return row.group
        }
        return null
    }

    function removeMessage(key, id) {
        var group = groupForKey(key)
        if (!group || !group.messages) return
        var messages = group.messages.filter(function(message) {
            return message && message.id !== id
        })
        if (!messages.length) {
            var card = root.cards[key]
            if (card) card.fadeOut()
            return
        }
        var rowIndex = -1
        for (var i = 0; i < notificationModel.count; ++i) {
            var row = notificationModel.get(i)
            if (row && row.group && row.group.key === key) {
                rowIndex = i
                break
            }
        }
        if (rowIndex >= 0)
            notificationModel.setProperty(rowIndex, "group", root.makeGroup(key, messages))
    }

    function removeGroup(key) {
        for (var i = 0; i < notificationModel.count; ++i) {
            var row = notificationModel.get(i)
            if (row && row.group && row.group.key === key) {
                notificationModel.remove(i)
                return
            }
        }
    }
}
