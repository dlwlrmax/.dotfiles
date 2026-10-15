import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.common

RowLayout {
    id: trayContainer
    spacing: 3
    // Never squeeze: shrinking boxes below image size causes visual overlap.
    // Deficit is absorbed by mpris (fillWidth) upstream in Bar.qml.
    Layout.minimumWidth: trayContainer.implicitWidth
    property Theme theme: Theme {}
    property int maxVisible: 5
    signal toggleOverflow()

    property int hiddenCount: Math.max(0, SystemTray.items.values.length - trayContainer.maxVisible)

    Repeater {
        // QsListModel gives keyed, diffed reuse. values.slice() built a fresh
        // JS array on every evaluation, resetting the model and recreating all
        // delegates (flicker).
        model: SystemTray.items

        delegate: TrayIcon {
            visible: index < trayContainer.maxVisible
        }
    }

    Rectangle {
        id: overflowBtn
        visible: trayContainer.hiddenCount > 0
        implicitWidth: 20
        implicitHeight: 18
        color: "transparent"
        opacity: overflowMouse.containsPress ? 0.55 : 1.0
        Behavior on opacity { NumberAnimation { duration: 80 } }

        Text {
            anchors.centerIn: parent
            text: "+" + trayContainer.hiddenCount
            color: overflowMouse.containsMouse ? trayContainer.theme.text : trayContainer.theme.subtext0
            font.pixelSize: 10
            font.bold: true
            font.family: trayContainer.theme.font
        }

        MouseArea {
            id: overflowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                overflowTip.suppressed = true
                trayContainer.toggleOverflow()
            }
        }

        BarTooltip {
            id: overflowTip
            target: overflowBtn
            theme: trayContainer.theme
            hovered: overflowMouse.containsMouse
            delay: 600
            text: "Show " + trayContainer.hiddenCount + " hidden icon" + (trayContainer.hiddenCount === 1 ? "" : "s")
        }
    }
}
