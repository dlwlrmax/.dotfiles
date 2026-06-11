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

    implicitWidth: 400
    implicitHeight: popupColumn.implicitHeight

    clip: false

    ColumnLayout {
        id: popupColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8
    }

    function onNotification(notif) {
        if (root.dnd) return
        if (!notif.tracked) return

        var card = popupCardComponent.createObject(popupColumn, {
            notifData: notif,
            notifTimes: root.notifTimes,
            theme: root.theme
        })

        card.dismissed.connect(function() {
            // Card self-destructs; no cleanup needed
        })
    }

    Component {
        id: popupCardComponent

        NotificationPopupCard {
            Layout.fillWidth: true
        }
    }
}
