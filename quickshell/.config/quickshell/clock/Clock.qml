import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common

Item {
    property Theme theme: Theme {}
    id: root
    signal togglePanel()
    implicitWidth: clock.implicitWidth
    implicitHeight: clock.implicitHeight

    Text {
        id: clock
        color: theme.text
        font.pixelSize: theme.fontSize
        font.family: theme.font
        font.bold: true

        // Ticks once a minute, aligned to the wall clock.
        text: Qt.formatDateTime(sysClock.date, "hh:mm dd/MM")
    }

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.togglePanel()
            }
        }
    }
}
