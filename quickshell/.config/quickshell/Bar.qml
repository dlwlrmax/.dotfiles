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
    signal toggleNotifPanel()
    signal toggleMprisPanel(int centerX)
    signal toggleVolumePanel()
    signal toggleWeatherPanel()
    signal toggleCalendarPanel()
    signal toggleSysUsagePanel()
    signal toggleNetPanel()
    signal toggleKdePanel(int centerX)
    signal toggleBatteryPanel(int centerX)
    property alias weatherWidget: barWeather
    property var kdeDataSource: null
    property var notifDataSource: null
    property var cpuDataSource: null
    property var netDataSource: null
    property var weatherDataSource: null
    property var volumeDataSource: null
    property var batteryDataSource: null

    DropShadow {
        anchors.fill: barRect
        source: barRect
        horizontalOffset: 0
        verticalOffset: 3
        radius: 5
        samples: 6
        color: "#30000000"
    }

    Rectangle {
        id: barRect
        anchors.fill: parent
        color: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.6)
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
                Layout.maximumWidth: (bar.width / 2) - 150 - workspaces.width
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
            width: Math.min(implicitWidth, parent.width / 2 - 80)
            spacing: 10
            clip: true
            property real mprisMaxWidth: {
                let used = 0
                let visible = 0
                for (let i = 0; i < children.length; i++) {
                    let c = children[i]
                    if (c !== mpris && c.visible) {
                        used += c.implicitWidth || 0
                        visible++
                    }
                }
                used += spacing * Math.max(0, visible - 1)
                let available = parent.width / 2 - anchors.rightMargin - 68
                return Math.max(100, available - used)
            }

            Mpris {
                id: mpris
                theme: bar.theme
                Layout.alignment: Qt.AlignVCenter
                maxWidth: rightSection.mprisMaxWidth
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
                dataSource: bar.cpuDataSource
                onTogglePanel: bar.toggleSysUsagePanel()
            }

            NetSpeed {
                theme: bar.theme
                Layout.alignment: Qt.AlignVCenter
                dataSource: bar.netDataSource
                onTogglePanel: bar.toggleNetPanel()
            }

            Separator {
                theme: bar.theme
                Layout.alignment: Qt.AlignVCenter
            }

            RowLayout {
                id: rightGroup
                spacing: 7
                Layout.alignment: Qt.AlignVCenter

                Weather {
                    id: barWeather
                    theme: bar.theme
                    Layout.alignment: Qt.AlignVCenter
                    dataSource: bar.weatherDataSource
                    onTogglePanel: bar.toggleWeatherPanel()
                }

                Volume {
                    theme: bar.theme
                    Layout.alignment: Qt.AlignVCenter
                    dataSource: bar.volumeDataSource
                    onTogglePanel: bar.toggleVolumePanel()
                }

                KDEConnect {
                    id: kdeWidget
                    theme: bar.theme
                    dataSource: bar.kdeDataSource
                    Layout.alignment: Qt.AlignVCenter
                    onTogglePanel: centerX => bar.toggleKdePanel(centerX)
                }

                IdleInhibitorWidget {
                    theme: bar.theme
                    Layout.alignment: Qt.AlignVCenter
                }

                Notification {
                    id: barNotif
                    theme: bar.theme
                    dataSource: bar.notifDataSource
                    Layout.alignment: Qt.AlignVCenter
                    onTogglePanel: bar.toggleNotifPanel()
                }
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
