import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

MouseArea {
    id: root
    property var theme
    width: row.implicitWidth
    height: row.implicitHeight

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 0

        Text {
            id: icon
            text: idleInhibitor.enabled ? "󰈈" : ""
            font.family: "JetBrainsMono Nerd Font Mono"
            font.pointSize: root.theme.fontSize + 5
            color: idleInhibitor.enabled ? root.theme.green : root.theme.red
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
        enabled: false
        window: inhibitWindow
    }

    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true

    onClicked: {
        idleInhibitor.enabled = !idleInhibitor.enabled
    }

    ToolTip {
        visible: parent.containsMouse
        text: idleInhibitor.enabled ? "Idle inhibitor on" : "Idle inhibitor off"
        delay: 2500
    }
}
