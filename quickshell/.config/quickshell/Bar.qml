import Quickshell
import Quickshell.Hyprland._Ipc
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: bar
    property Theme theme: Theme {}
    required property var monitor

    color: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.85)
    radius: 12

    RowLayout {
        id: leftSection
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Workspaces {
            monitor: bar.monitor
            Layout.alignment: Qt.AlignVCenter
        }

        WindowTitle {
            Layout.alignment: Qt.AlignVCenter
        }
    }

    Clock {
        id: centerClock
        anchors.centerIn: parent
    }

    RowLayout {
        id: rightSection
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Weather {
            theme: bar.theme
            Layout.alignment: Qt.AlignVCenter
        }

        Separator {
            theme: bar.theme
            Layout.alignment: Qt.AlignVCenter
        }

        Cpu {
            theme: bar.theme
            Layout.alignment: Qt.AlignVCenter
        }

        Separator {
            theme: bar.theme
            Layout.alignment: Qt.AlignVCenter
        }

        NetSpeed {
            theme: bar.theme
            Layout.alignment: Qt.AlignVCenter
        }

        Separator {
            theme: bar.theme
            Layout.alignment: Qt.AlignVCenter
        }

        Volume {
            theme: bar.theme
            Layout.alignment: Qt.AlignVCenter
        }

        Separator {
            theme: bar.theme
            Layout.alignment: Qt.AlignVCenter
        }

        Notification {
            theme: bar.theme
            Layout.alignment: Qt.AlignVCenter
        }

        SystemTray {
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
