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
    property Theme theme: ThemeStore
    signal toggleOverflow()

    Component.onCompleted: ShellState.loadTrayPins()

    // Items kept in the bar come from the pin list (first 5 until customised).
    readonly property int hiddenCount: {
        var items = SystemTray.items.values, pins = ShellState.trayPins, n = 0
        for (var i = 0; i < items.length; i++)
            if (!(pins === null ? i < ShellState.trayDefaultVisible : pins.indexOf(items[i].id) >= 0)) n++
        return n
    }

    Repeater {
        // QsListModel gives keyed, diffed reuse. values.slice() built a fresh
        // JS array on every evaluation, resetting the model and recreating all
        // delegates (flicker).
        model: SystemTray.items

        delegate: TrayIcon {
            visible: ShellState.trayPins === null ? index < ShellState.trayDefaultVisible : ShellState.trayPins.indexOf(modelData.id) >= 0
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
            font.pixelSize: trayContainer.theme.fontSize - 2
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
