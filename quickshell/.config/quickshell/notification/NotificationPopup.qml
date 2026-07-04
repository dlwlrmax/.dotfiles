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
    // Backing data source (notifData Item in shell.qml). Used to broadcast
    // dismiss requests across screens so closing one popup closes all.
    property var dataSource: null

    implicitWidth: 400
    implicitHeight: popupColumn.implicitHeight

    clip: false

    // Track live cards by notif id so we can fade the matching one when
    // another screen requests dismiss.
    property var cards: ({})

    ColumnLayout {
        id: popupColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8
    }

    // React to broadcast dismiss from any screen.
    Connections {
        target: root.dataSource
        enabled: root.dataSource !== null
        function onDismissPopup(notifId) {
            var card = root.cards[notifId]
            if (card) card.fadeOut()
        }
    }

    function onNotification(notif) {
        if (root.dnd) return
        if (!notif.tracked) return

        var card = popupCardComponent.createObject(popupColumn, {
            notifData: notif,
            notifTimes: root.notifTimes,
            theme: root.theme
        })

        root.cards[notif.id] = card

        card.dismissed.connect(function() {
            // Card self-destructs; just drop from map.
            delete root.cards[notif.id]
        })

        // User-initiated close (× or auto-dismiss timer) on this screen:
        // broadcast to other screens before local fade completes.
        card.dismissRequested.connect(function() {
            if (root.dataSource) root.dataSource.requestDismissPopup(notif.id)
        })
    }

    Component {
        id: popupCardComponent

        NotificationPopupCard {
            Layout.fillWidth: true
        }
    }
}