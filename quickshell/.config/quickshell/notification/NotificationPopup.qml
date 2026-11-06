import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.notification
import qs.common
import "Group.js" as Grp

Item {
    id: root
    property Theme theme: ThemeStore
    property var notifTimes: ({})
    property bool dnd: false
    // Gaming quiet mode for this screen: only critical notifications pop up.
    property bool quiet: false
    property int maxWidth: 460
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
            expireTimeout: notif.expireTimeout || 0,
            hasReply: !!notif.hasInlineReply,
            replyPlaceholder: notif.inlineReplyPlaceholder || ""
        }
    }

    // Always emit the same role shape: object keys fixed, messages always an
    // array of plain objects. Prevents "role of different type [List ->
    // VariantMap]" and keeps Repeater delegate bindings stable.
    function makeGroup(key, messages) {
        return {
            key: key,
            appKey: messages.length ? root.appKey(messages[0]) : "",
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
                    SpringAnimation { spring: root.theme.springMove; damping: root.theme.dampingStack; epsilon: root.theme.epsilonMove }
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
                replyHandler: function(notifId, text) {
                    return !!(root.dataSource && root.dataSource.sendReply
                              && root.dataSource.sendReply(notifId, text))
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

    function appKey(notif) { return Grp.appKey(notif) }

    // Unique per card: one app can own several cards when others interrupt it.
    property int _groupSeq: 0

    // Card is fading out (or gone): anything added to it would never be seen.
    function isLeaving(key) {
        var card = root.cards[key]
        return !!card && (card._dismissing || card._dismissed)
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

    // Same notification id re-sent with new text: refresh its message in place and
    // bring the group to the top. If its card is already gone, show it again.
    function onNotificationUpdated(notif) {
        if (root.dnd || !notif) return
        if (root.quiet && notif.urgency !== NotificationUrgency.Critical) return
        for (var i = 0; i < notificationModel.count; ++i) {
            var row = notificationModel.get(i)
            var group = row ? row.group : null
            if (!group || !group.messages) continue
            var rest = group.messages.filter(function(m) { return m && m.id !== notif.id })
            if (rest.length === group.messages.length) continue
            // Card already on its way out: show the update on a fresh card.
            if (root.isLeaving(group.key)) break
            var messages = [root.snapshotNotif(notif)].concat(rest)
            notificationModel.setProperty(i, "group", root.makeGroup(group.key, messages))
            notificationModel.move(i, 0, 1)
            return
        }
        root.onNotification(notif)
    }

    function onNotification(notif) {
        if (root.dnd || !notif) return
        if (root.quiet && notif.urgency !== NotificationUrgency.Critical) return
        if (!notif.tracked) return

        var appKey = root.appKey(notif)
        var snapshot = root.snapshotNotif(notif)
        // Join only the newest card: another app in between starts a new card.
        if (notificationModel.count > 0) {
            var top = notificationModel.get(0)
            var existing = top ? top.group : null
            if (existing && existing.appKey === appKey && !root.isLeaving(existing.key)) {
                var messages = (existing.messages || []).slice()
                messages.unshift(snapshot)
                notificationModel.setProperty(0, "group", root.makeGroup(existing.key, messages))
                return
            }
        }

        notificationModel.insert(0, {
            group: root.makeGroup(appKey + "#" + (root._groupSeq++), [snapshot])
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
