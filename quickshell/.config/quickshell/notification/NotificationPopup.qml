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

    ListModel {
        id: notificationModel
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

                // Let card finish its own fade/destroy before removing model row.
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
            var group = notificationModel.get(i).group
            for (var j = 0; j < group.messages.length; ++j) {
                if (group.messages[j].id === notifId) return root.cards[group.key]
            }
        }
        return null
    }

    function onNotification(notif) {
        if (root.dnd || !notif) return
        if (!notif.tracked) return

        var key = root.appKey(notif)
        for (var i = 0; i < notificationModel.count; ++i) {
            var existing = notificationModel.get(i).group
            if (existing.key !== key) continue

            var messages = existing.messages.slice()
            messages.unshift(notif)
            var updated = {
                key: key,
                appName: notif.appName || existing.appName || "Unknown",
                latest: notif,
                count: messages.length,
                messages: messages
            }
            notificationModel.setProperty(i, "group", updated)
            notificationModel.move(i, 0, 1)
            return
        }

        notificationModel.insert(0, {
            group: {
                key: key,
                appName: notif.appName || "Unknown",
                latest: notif,
                count: 1,
                messages: [notif]
            }
        })
    }

    function dismissGroup(key) {
        var group = groupForKey(key)
        if (!group) return
        for (var i = 0; i < group.messages.length; ++i) {
            if (root.dataSource && root.dataSource.requestDismissPopup)
                root.dataSource.requestDismissPopup(group.messages[i].id)
        }
    }

    function groupForKey(key) {
        for (var i = 0; i < notificationModel.count; ++i) {
            if (notificationModel.get(i).group.key === key)
                return notificationModel.get(i).group
        }
        return null
    }

    function removeMessage(key, id) {
        var group = groupForKey(key)
        if (!group) return
        var messages = group.messages.filter(function(message) { return message.id !== id })
        if (!messages.length) {
            var card = root.cards[key]
            if (card) card.fadeOut()
            return
        }
        var updated = {
            key: key,
            appName: group.appName,
            latest: messages[0],
            count: messages.length,
            messages: messages
        }
        for (var i = 0; i < notificationModel.count; ++i) {
            if (notificationModel.get(i).group.key === key) {
                notificationModel.setProperty(i, "group", updated)
                return
            }
        }
    }

    function removeGroup(key) {
        for (var i = 0; i < notificationModel.count; ++i) {
            if (notificationModel.get(i).group.key === key) {
                notificationModel.remove(i)
                return
            }
        }
    }
}
