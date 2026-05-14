import Quickshell
import Quickshell.Hyprland._Ipc
import QtQuick
import QtQuick.Layouts

    Rectangle {
    id: bar
    property Theme theme: Theme {}
    required property var monitor

    color: theme.base

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 4
        spacing: 12

        Workspaces {
            monitor: bar.monitor
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
        }

        WindowTitle {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
        }

        Item { Layout.fillWidth: true }

        Clock {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
        }

        Item { Layout.fillWidth: true }

        Weather {
            theme: bar.theme
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }

        Cpu {
            theme: bar.theme
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }

        NetSpeed {
            theme: bar.theme
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }

        Volume {
            theme: bar.theme
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }

        Notification {
            theme: bar.theme
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }

        SystemTray {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }
    }
}
