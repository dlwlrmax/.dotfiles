import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.common

MouseArea {
    id: root
    property Theme theme: ThemeStore
    width: row.implicitWidth
    implicitHeight: row.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    RowLayout {
        id: row
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 0
        spacing: 0

        Text {
            id: icon
            text: idleInhibitor.enabled ? "󰈈" : ""
            font.family: root.theme.font
            font.pixelSize: root.theme.fontSize + 9
            color: idleInhibitor.enabled ? root.theme.green : root.theme.overlay1
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // hidden window for idle inhibitor — avoids relying on parent window binding
    PanelWindow {
        id: inhibitWindow
        visible: false
        implicitWidth: 0
        implicitHeight: 0
        color: "transparent"
        mask: Region {}
    }

    IdleInhibitor {
        id: idleInhibitor
        enabled: ShellState.idleInhibit
        window: inhibitWindow
    }

    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true

    onClicked: {
        tip.suppressed = true
        ShellState.idleInhibit = !ShellState.idleInhibit
    }

    BarTooltip {
        id: tip
        target: root
        theme: root.theme
        hovered: root.containsMouse
        delay: 800

        Text {
            text: idleInhibitor.enabled ? "Idle inhibitor on" : "Idle inhibitor off"
            color: idleInhibitor.enabled ? root.theme.green : root.theme.text
            font.pixelSize: root.theme.fontSize - 1
            font.weight: Font.Medium
            font.family: root.theme.font
        }
        Text {
            text: idleInhibitor.enabled ? "Screen won't lock or sleep" : "Screen locks and sleeps normally"
            color: root.theme.subtext0
            font.pixelSize: root.theme.fontSize - 2
            font.family: root.theme.font
        }
    }
}
