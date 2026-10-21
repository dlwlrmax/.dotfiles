import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import "../common/CalendarLogic.js" as Cal

Item {
    property Theme theme: ThemeStore
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

    BarTooltip {
        target: root
        theme: root.theme
        hovered: clockMa.containsMouse
        text: Cal.tooltipText(Cal.keyOf(sysClock.date))
    }

    MouseArea {
        id: clockMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.togglePanel()
            }
        }
    }
}
