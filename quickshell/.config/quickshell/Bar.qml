import Quickshell
import Quickshell.Hyprland._Ipc
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.common
import qs.workspaces
import qs.windowtitle
import qs.clock
import qs.mpris
import qs.cpu
import qs.netspeed
import qs.weather
import qs.volume
import qs.battery
import qs.idleinhibitor
import qs.kdeconnect
import qs.notification
import qs.systemtray

Item {
    id: bar
    property Theme theme: Theme {}
    required property var monitor
    property var kdeData: null  // shared KDEConnectData
    signal toggleNotifPanel()
    signal toggleMprisPanel(int centerX)
    signal toggleVolumePanel()
    signal toggleWeatherPanel()
    signal toggleCalendarPanel()
    signal toggleSysUsagePanel()
    signal toggleKdePanel(int centerX)
    signal toggleBatteryPanel(int centerX)

    DropShadow {
        anchors.fill: barRect
        source: barRect
        horizontalOffset: 0
        verticalOffset: 3
        radius: 5
        samples: 10
        color: "#30000000"
    }

    Rectangle {
        id: barRect
        anchors.fill: parent
        color: theme.color
        radius: 12

        RowLayout {
            id: leftSection
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Workspaces {
                id: workspaces
                monitor: bar.monitor
                Layout.alignment: Qt.AlignVCenter
            }

            WindowTitle {
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: (bar.width / 2) - 100 - workspaces.width
            }
        }

        Clock {
            id: centerClock
            anchors.centerIn: parent
            onTogglePanel: bar.toggleCalendarPanel()
        }

        RowLayout {
            id: rightSection
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            Layout.maximumWidth: parent.width / 2 - 60
            spacing: 12
            clip: true

            Mpris {
                id: mpris
                theme: bar.theme
                Layout.alignment: Qt.AlignVCenter
                onTogglePanel: centerX => bar.toggleMprisPanel(centerX)
            }

            Separator {
                theme: bar.theme
                Layout.alignment: Qt.AlignVCenter
                visible: mpris.visible
            }

            Cpu {
                theme: bar.theme
                Layout.alignment: Qt.AlignVCenter
                onTogglePanel: bar.toggleSysUsagePanel()
            }

            NetSpeed {
                theme: bar.theme
                Layout.alignment: Qt.AlignVCenter
            }

            Separator {
                theme: bar.theme
                Layout.alignment: Qt.AlignVCenter
            }

            Weather {
                theme: bar.theme
                Layout.alignment: Qt.AlignVCenter
                onTogglePanel: bar.toggleWeatherPanel()
            }


            Volume {
                theme: bar.theme
                Layout.alignment: Qt.AlignVCenter
                onTogglePanel: bar.toggleVolumePanel()
            }

            KDEConnect {
                id: kdeWidget
                theme: bar.theme
                dataSource: bar.kdeData
                Layout.alignment: Qt.AlignVCenter
                onTogglePanel: centerX => bar.toggleKdePanel(centerX)
            }

            Battery {
                theme: bar.theme
                Layout.alignment: Qt.AlignVCenter
                onTogglePanel: centerX => bar.toggleBatteryPanel(centerX)
            }


            IdleInhibitor {
                theme: bar.theme
                Layout.alignment: Qt.AlignVCenter
            }

            Notification {
                theme: bar.theme
                Layout.alignment: Qt.AlignVCenter
                onTogglePanel: bar.toggleNotifPanel()
            }

            Separator {
                theme: bar.theme
                Layout.alignment: Qt.AlignVCenter
            }

            SystemTray {
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
